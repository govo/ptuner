//
//  MicrophoneAudioCapture.swift
//  PTuner
//
//  实时调音器的麦克风采集层。
//
//  职责只有两件事：把麦克风缓冲重采样成 CREPE 需要的 16 kHz 单声道 Float32，
//  并在多音通道打开时再重采样一份 22050 Hz 给 Basic Pitch；然后按「从采集
//  开始算起的采样下标」交给上层。音频时间轴由采样计数推导，与墙面时钟解耦。
//

import AVFoundation
import Foundation

#if os(macOS)
import CoreAudio
#endif

/// 麦克风授权状态，供设置页展示与引导。
nonisolated enum MicrophonePermissionStatus: Equatable {
    case undetermined
    case granted
    case denied
}

nonisolated enum MicrophoneCaptureError: LocalizedError {
    case permissionDenied
    case noInput
    case formatUnavailable
    case converterUnavailable
    case deviceUnavailable(String)
    case engineStartFailed(Error)
    case engineInterrupted

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return L10n.tr("没有麦克风权限")
        case .noInput:
            return L10n.tr("没有检测到可用的麦克风输入")
        case .formatUnavailable:
            return L10n.tr("麦克风输入格式不可用")
        case .converterUnavailable:
            return L10n.tr("无法创建音频重采样器")
        case .deviceUnavailable(let name):
            return L10n.tr("音频输入设备不可用: %@", name)
        case .engineStartFailed(let error):
            return L10n.tr("音频引擎启动失败: %@", error.localizedDescription)
        case .engineInterrupted:
            return L10n.tr("音频采集被系统中断")
        }
    }
}

nonisolated final class MicrophoneAudioCapture: @unchecked Sendable {

    /// 目标采样率与 CREPE 保持一致。
    static let targetSampleRate = Double(CrepeConstants.sampleRate)
    /// Basic Pitch 的目标采样率。
    static let polyphonicSampleRate = Double(BasicPitchConstants.sampleRate)

    /// 重采样后的 16 kHz 单声道样本，以及这批样本第一个点在整段录音里的下标。
    var onSamples: (([Float], Int) -> Void)?
    /// 重采样后的 22050 Hz 单声道样本（Basic Pitch 多音通道）。
    /// 只有通过 setPolyphonicCaptureEnabled(true) 打开时才会产生。
    var onPolySamples: (([Float], Int) -> Void)?
    var onError: ((Error) -> Void)?

    /// macOS 下指定 Core Audio 输入设备；nil 表示跟随系统默认。
    var preferredInputDeviceUID: String?

    /// 每次重新开始采集时重建，确保输入设备与采样格式按当前系统状态重新绑定。
    private var engine = AVAudioEngine()
    private var converter: AVAudioConverter?
    private var outputFormat: AVAudioFormat?
    private var sampleCursor = 0

    private var polyConverter: AVAudioConverter?
    private var polyOutputFormat: AVAudioFormat?
    private var polySampleCursor = 0
    private let polyEnableLock = NSLock()
    private var polyCaptureEnabled = false

    /// 把单声道样本包装成 AVAudioConverter 的输入缓冲，两个目标采样率共用。
    private var inputScratch: AVAudioPCMBuffer?
    private var inputScratchFormat: AVAudioFormat?

    private var isRunning = false
    private var observers: [NSObjectProtocol] = []

    // MARK: - 权限

    /// 当前授权状态。不会触发系统弹窗。
    static var permissionStatus: MicrophonePermissionStatus {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return .granted
        case .denied:
            return .denied
        case .undetermined:
            return .undetermined
        @unknown default:
            return .denied
        }
    }

    /// 请求（或读取）麦克风权限。已授权时不会弹窗。
    static func requestPermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted:
            return true
        case .denied:
            return false
        case .undetermined:
            break
        @unknown default:
            break
        }

        return await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    // MARK: - 生命周期

    func start() throws {
        guard !isRunning else { return }

        // 用全新的引擎重新绑定输入设备，避免复用上一台设备的格式缓存。
        engine = AVAudioEngine()

        #if os(iOS) || os(visionOS)
        let session = AVAudioSession.sharedInstance()
        do {
            // playAndRecord 让调音时也能播放参考音；defaultToSpeaker 保证走扬声器而不是听筒。
            // measurement 关掉系统降噪/自动增益，避免把音高和电平改掉。
            try session.setCategory(.playAndRecord,
                                    mode: .measurement,
                                    options: [.defaultToSpeaker, .allowBluetoothHFP])
            try session.setActive(true)
        } catch {
            throw MicrophoneCaptureError.engineStartFailed(error)
        }
        #endif

        do {
            try startEngineInput()
        } catch {
            deactivateSession()
            throw error
        }

        isRunning = true
        installObservers()
    }

    private func startEngineInput() throws {
        let input = engine.inputNode

        #if os(macOS)
        try applyPreferredInputDevice(to: input)
        #endif

        let inputFormat = input.outputFormat(forBus: 0)
        guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else {
            throw MicrophoneCaptureError.noInput
        }

        let crepe = try makeConverter(from: inputFormat, to: Self.targetSampleRate)
        let poly = try makeConverter(from: inputFormat, to: Self.polyphonicSampleRate)
        applyConverters(crepe: crepe, poly: poly)

        // iOS / macOS 27 起 installTap 改为可抛错的新入口。它通过
        // NS_REFINED_FOR_SWIFT 导入后，Swift 形式是 __installTap(..., error: (), block:)。
        // 较低系统版本仍使用旧的 installTap。
        do {
            if #available(iOS 27.0, macOS 27.0, visionOS 27.0, *) {
                try input.__installTap(onBus: 0, bufferSize: 2048, format: inputFormat, error: (), block: { [weak self] buffer, _ in
                    self?.handleTap(buffer)
                })
            } else {
                input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { [weak self] buffer, _ in
                    self?.handleTap(buffer)
                }
            }
        } catch {
            clearConverters()
            throw MicrophoneCaptureError.engineStartFailed(error)
        }

        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            clearConverters()
            throw MicrophoneCaptureError.engineStartFailed(error)
        }
    }

    #if os(macOS)
    /// 在启动引擎前把输入节点绑定到用户选择的 Core Audio 设备。
    /// 未选择时也显式绑定当前系统默认输入，避免沿用引擎缓存的旧设备。
    private func applyPreferredInputDevice(to input: AVAudioInputNode) throws {
        let deviceID: AudioDeviceID?

        if let uid = preferredInputDeviceUID {
            guard let selected = AudioInputDevices.deviceID(forUID: uid) else {
                throw MicrophoneCaptureError.deviceUnavailable(
                    AudioInputDevices.all().first(where: { $0.id == uid })?.name ?? uid
                )
            }
            deviceID = selected
        } else {
            deviceID = AudioInputDevices.defaultInputDeviceID()
        }

        guard let deviceID else { return }

        do {
            if #available(macOS 27.0, *) {
                try input.withAUAudioUnit { audioUnit in
                    try audioUnit.setDeviceID(deviceID)
                }
            } else {
                try input.auAudioUnit.setDeviceID(deviceID)
            }
        } catch {
            // 跟随系统默认时，绑定失败就交给 AVAudioEngine 自行选择；
            // 用户明确选择的设备则必须绑定成功。
            if let uid = preferredInputDeviceUID {
                throw MicrophoneCaptureError.deviceUnavailable(uid)
            }
        }
    }
    #endif

    func stop() {
        guard isRunning else { return }
        isRunning = false
        removeObservers()

        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        clearConverters()
        setPolyphonicCaptureEnabled(false)
        deactivateSession()
    }

    /// 打开/关闭第二路 22050 Hz 重采样。关闭时不做任何额外转换。
    ///
    /// 中途打开时，把 22050 的采样游标接到当前 16 kHz 游标对应的时刻上，
    /// 这样多音通道的时间戳和本次录音的时间轴是同一个原点。
    func setPolyphonicCaptureEnabled(_ enabled: Bool) {
        polyEnableLock.lock()
        if enabled, !polyCaptureEnabled {
            let ratio = Self.polyphonicSampleRate / Self.targetSampleRate
            polySampleCursor = Int((Double(sampleCursor) * ratio).rounded())
        }
        polyCaptureEnabled = enabled
        polyEnableLock.unlock()
    }

    // MARK: - 转换器

    private func makeConverter(from inputFormat: AVAudioFormat,
                               to sampleRate: Double) throws -> (converter: AVAudioConverter, target: AVAudioFormat) {
        guard let target = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                         sampleRate: sampleRate,
                                         channels: 1,
                                         interleaved: false) else {
            throw MicrophoneCaptureError.formatUnavailable
        }
        guard let created = AVAudioConverter(from: inputFormat, to: target) else {
            throw MicrophoneCaptureError.converterUnavailable
        }
        created.sampleRateConverterQuality = AVAudioQuality.max.rawValue
        created.sampleRateConverterAlgorithm = AVSampleRateConverterAlgorithm_Mastering
        return (created, target)
    }

    private func applyConverters(crepe: (converter: AVAudioConverter, target: AVAudioFormat),
                                 poly: (converter: AVAudioConverter, target: AVAudioFormat)) {
        converter = crepe.converter
        outputFormat = crepe.target
        sampleCursor = 0

        polyConverter = poly.converter
        polyOutputFormat = poly.target
        polySampleCursor = 0

        inputScratch = nil
        inputScratchFormat = nil
        setPolyphonicCaptureEnabled(false)
    }

    private func clearConverters() {
        converter = nil
        outputFormat = nil
        polyConverter = nil
        polyOutputFormat = nil
        inputScratch = nil
        inputScratchFormat = nil
    }

    private func deactivateSession() {
        #if os(iOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    // MARK: - 采集

    /// AVAudioEngine tap 入口：取出第一个声道交给统一的处理流程。
    private func handleTap(_ buffer: AVAudioPCMBuffer) {
        let count = Int(buffer.frameLength)
        guard count > 0, let channel = buffer.floatChannelData?[0] else { return }
        let samples = Array(UnsafeBufferPointer(start: channel, count: count))
        processMonoInput(samples, sampleRate: buffer.format.sampleRate)
    }

    /// 单声道输入的统一入口：16 kHz 给 CREPE，22050 Hz 给 Basic Pitch。
    private func processMonoInput(_ samples: [Float], sampleRate: Double) {
        guard !samples.isEmpty,
              let input = makeInputBuffer(samples: samples, sampleRate: sampleRate),
              let converter,
              let outputFormat else { return }

        let ratio = outputFormat.sampleRate / sampleRate
        let capacity = AVAudioFrameCount(Double(samples.count) * ratio) + 2048
        guard let output = AVAudioPCMBuffer(pcmFormat: outputFormat, frameCapacity: capacity) else { return }

        var provided = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            if provided {
                outStatus.pointee = .noDataNow
                return nil
            }
            provided = true
            outStatus.pointee = .haveData
            return input
        }

        if status == .error {
            if let conversionError {
                onError?(conversionError)
            } else {
                onError?(MicrophoneCaptureError.converterUnavailable)
            }
            return
        }

        if output.frameLength > 0, let channel = output.floatChannelData?[0] {
            let converted = Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))
            // 游标和「多音开关」共用一把锁，保证中途打开多音时能读到一致的时间原点。
            polyEnableLock.lock()
            let startIndex = sampleCursor
            sampleCursor += converted.count
            polyEnableLock.unlock()
            onSamples?(converted, startIndex)
        }

        processPolyphonic(input)
    }

    /// 把样本塞进可复用的输入缓冲，避免每个音频回调都新建 AVAudioPCMBuffer。
    private func makeInputBuffer(samples: [Float], sampleRate: Double) -> AVAudioPCMBuffer? {
        let needed = samples.count
        if inputScratch == nil
            || inputScratchFormat?.sampleRate != sampleRate
            || (inputScratch?.frameCapacity ?? 0) < AVAudioFrameCount(needed) {
            guard let format = AVAudioFormat(commonFormat: .pcmFormatFloat32,
                                             sampleRate: sampleRate,
                                             channels: 1,
                                             interleaved: false),
                  let scratch = AVAudioPCMBuffer(pcmFormat: format,
                                                 frameCapacity: AVAudioFrameCount(max(needed, 8192))) else {
                return nil
            }
            inputScratch = scratch
            inputScratchFormat = format
        }

        guard let scratch = inputScratch, let destination = scratch.floatChannelData?[0] else { return nil }
        samples.withUnsafeBufferPointer { source in
            if let base = source.baseAddress {
                destination.update(from: base, count: needed)
            }
        }
        scratch.frameLength = AVAudioFrameCount(needed)
        return scratch
    }

    /// 同一份输入缓冲再重采样一份 22050 Hz 给 Basic Pitch。
    /// 只有在多音开关打开时才做，避免常态下的额外开销。
    private func processPolyphonic(_ buffer: AVAudioPCMBuffer) {
        polyEnableLock.lock()
        let enabled = polyCaptureEnabled
        polyEnableLock.unlock()
        guard enabled, let converter = polyConverter, let format = polyOutputFormat else { return }

        let ratio = format.sampleRate / buffer.format.sampleRate
        let capacity = AVAudioFrameCount(Double(buffer.frameLength) * ratio) + 2048
        guard let output = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }

        var provided = false
        var conversionError: NSError?
        let status = converter.convert(to: output, error: &conversionError) { _, outStatus in
            if provided {
                outStatus.pointee = .noDataNow
                return nil
            }
            provided = true
            outStatus.pointee = .haveData
            return buffer
        }

        // 多音通道的转换失败不应该中断主调音通道，下一批缓冲再试即可。
        guard status != .error,
              output.frameLength > 0,
              let channel = output.floatChannelData?[0] else { return }

        let samples = Array(UnsafeBufferPointer(start: channel, count: Int(output.frameLength)))

        polyEnableLock.lock()
        let stillEnabled = polyCaptureEnabled
        let startIndex = polySampleCursor
        if stillEnabled {
            polySampleCursor += samples.count
        }
        polyEnableLock.unlock()

        guard stillEnabled else { return }
        onPolySamples?(samples, startIndex)
    }

    // MARK: - 系统事件

    private func installObservers() {
        let center = NotificationCenter.default

        observers.append(center.addObserver(forName: .AVAudioEngineConfigurationChange,
                                            object: engine,
                                            queue: nil) { [weak self] _ in
            self?.onError?(MicrophoneCaptureError.engineInterrupted)
        })

        #if os(iOS) || os(visionOS)
        if #available(iOS 27.0, visionOS 27.0, *) {
            // iOS 27 起用 didBecomeInactive 取代已废弃的 interruption 通知。
            observers.append(center.addObserver(forName: AVAudioSession.didBecomeInactiveNotification,
                                                object: nil,
                                                queue: nil) { [weak self] _ in
                self?.onError?(MicrophoneCaptureError.engineInterrupted)
            })
        } else {
            observers.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
                                                object: nil,
                                                queue: nil) { [weak self] notification in
                guard let raw = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      AVAudioSession.InterruptionType(rawValue: raw) == .began else { return }
                self?.onError?(MicrophoneCaptureError.engineInterrupted)
            })
        }
        #endif
    }

    private func removeObservers() {
        let center = NotificationCenter.default
        observers.forEach { center.removeObserver($0) }
        observers.removeAll()
    }
}
