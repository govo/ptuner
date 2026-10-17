//
//  TunerController.swift
//  PTuner
//
//  调音器的可观察封装。界面只需要持有本对象，绑定 @Published 状态即可：
//  权限、模型加载、麦克风启停、单音/多音切换与实时读数都在这里完成。
//
//  与引擎的分工：
//  - TunerEngine 在分析队列上产出原始更新，不关心线程；
//  - TunerController 固定切回主线程，做展示用的平滑与状态文案。
//

import Combine
import Foundation

/// 需要 Basic Pitch 多音通道的功能。多个功能可以同时占用，任意一个存在时保持开启。
public nonisolated enum PolyphonyDemand: Hashable, Sendable {
    case multiStringTuning
    case chordRecognition
}

@MainActor
public final class TunerController: ObservableObject {

    // MARK: - 运行状态

    @Published public private(set) var isRunning = false
    @Published public private(set) var isStarting = false
    @Published public private(set) var statusText = L10n.tr("点击开始，允许麦克风后即可实时调音")
    @Published public private(set) var permissionDenied = false
    @Published public private(set) var errorText: String?

    /// 音频帧级的实时读数（电平、音高、多音读数）。
    ///
    /// 这是普通属性，不是 `@Published`：控制器对外发布的变化只包含启停、
    /// 权限、设备与配置等低频状态。调音页 / 和弦页观察 `realtime` 本身，
    /// 设置页、乐器页等观察控制器时不会被监听中的高频刷新牵连。
    public let realtime = TunerRealtimeState()

    // MARK: - 多音识别（Basic Pitch）

    @Published public private(set) var polyphonicEnabled = false
    /// 当前占用多音通道的功能集合。任意一个存在时 Basic Pitch 保持开启。
    @Published public private(set) var polyphonyDemands: Set<PolyphonyDemand> = []
    /// 调音页的多音调音开关状态。
    public var isMultiStringTuningRequested: Bool {
        polyphonyDemands.contains(.multiStringTuning)
    }
    /// 同时识别的最大音数（2 ~ 12）。
    @Published public private(set) var maxPolyphony = 6
    @Published public private(set) var isPreparingPoly = false

    // MARK: - 输入源

    /// 当前实际使用的输入设备名称。未开始监听时也会尽量给出系统默认设备。
    @Published public private(set) var activeInputDeviceName: String?

    private var engine: TunerEngine?
    private var startTask: Task<Void, Never>?
    private var displayMidi: Double?
    private var lastReportedNoteCount = 0
    /// 显示平滑系数。由设置页的「稳定度」决定。
    private var displaySmoothing: Double = 0.35
    private var preferredInputDeviceUID: String?
    private var inputChangeTask: Task<Void, Never>?
    /// 引擎启动后短时间内忽略配置变化通知，避免自触发的重启循环。
    private var suppressInterruptRestartsUntil = Date.distantPast
    /// 自动重启的时间戳，用于限制短时间内反复重启。
    private var automaticRestartTimestamps: [Date] = []

    #if os(macOS)
    private let inputMonitor = AudioInputDeviceMonitor.shared
    private var inputMonitorCancellable: AnyCancellable?
    private var lastKnownDefaultInputUID: String?
    #endif

    public init() {
        refreshActiveInputDeviceName()

        #if os(macOS)
        inputMonitor.start()
        lastKnownDefaultInputUID = inputMonitor.defaultDeviceUID
        inputMonitorCancellable = inputMonitor.$changeToken
            .dropFirst()
            .sink { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.handleInputDevicesChanged()
                }
            }
        refreshActiveInputDeviceName()
        #endif
    }

    // MARK: - 麦克风权限

    /// 请求（或读取）麦克风权限。界面可在展示说明页时提前调用。
    public static func requestMicrophonePermission() async -> Bool {
        await MicrophoneAudioCapture.requestPermission()
    }

    // MARK: - 启停

    public func toggle() {
        if isRunning {
            stop()
        } else {
            start()
        }
    }

    public func start() {
        startCapture(isAutomatic: false)
    }

    private func startCapture(isAutomatic: Bool) {
        guard !isRunning, !isStarting else { return }

        if !isAutomatic {
            automaticRestartTimestamps.removeAll()
        }

        errorText = nil
        permissionDenied = false
        isStarting = true
        statusText = L10n.tr("请求麦克风权限…")

        startTask?.cancel()
        startTask = Task { [weak self] in
            guard let self else { return }

            let granted = await MicrophoneAudioCapture.requestPermission()
            guard !Task.isCancelled else { return }
            guard granted else {
                self.isStarting = false
                self.permissionDenied = true
                self.statusText = L10n.tr("没有麦克风权限")
                return
            }

            self.statusText = L10n.tr("加载音高模型…")

            do {
                let prepared = try await self.prepareEngine()
                guard !Task.isCancelled else { return }

                self.attachCallbacks(to: prepared)
                self.statusText = L10n.tr("启动麦克风…")
                self.resetRealtimeState()
                prepared.preferredInputDeviceUID = self.preferredInputDeviceUID

                try prepared.start()

                self.isRunning = true
                self.isStarting = false
                self.suppressInterruptRestartsUntil = Date().addingTimeInterval(2.0)
                self.refreshActiveInputDeviceName()
                self.statusText = L10n.tr("正在监听…")

                if self.polyphonicEnabled {
                    self.enablePolyphonic(on: prepared)
                }
            } catch {
                self.isStarting = false
                self.isRunning = false
                self.isPreparingPoly = false
                self.errorText = error.localizedDescription
                self.statusText = L10n.tr("启动失败: %@", error.localizedDescription)
            }
        }
    }

    public func stop() {
        startTask?.cancel()
        startTask = nil
        inputChangeTask?.cancel()
        inputChangeTask = nil

        engine?.stop()
        isRunning = false
        isStarting = false
        isPreparingPoly = false
        realtime.liveMidi = nil
        displayMidi = nil
        realtime.liveNote = nil
        realtime.liveConfidence = 0
        realtime.level = 0
        // 停止后不再有「正在发声」的音，表盘清空；历史音块保留。
        realtime.polyReadouts = []

        if polyphonicEnabled {
            statusText = realtime.polyNotes.isEmpty
                ? L10n.tr("已停止 · 多音识别已关闭")
                : L10n.tr("已停止 · 多音识别共 %d 个音", realtime.polyNotes.count)
        } else {
            statusText = realtime.notes.isEmpty
                ? L10n.tr("已停止")
                : L10n.tr("已停止 · 本次识别 %d 个音", realtime.notes.count)
        }
    }

    /// 清空音符与曲线；运行中保持音频时间轴继续滚动。
    public func clear() {
        engine?.clearNotes()
        realtime.reset()
        displayMidi = nil
        lastReportedNoteCount = 0
    }

    // MARK: - 显示设置

    /// 调整实时读数的平滑程度（0.05 ~ 1.0，越大越跟手）。
    public func setDisplaySmoothing(_ value: Double) {
        displaySmoothing = min(max(value, 0.05), 1.0)
    }

    /// 指定 macOS 输入设备；运行中切换会重启采集。
    public func setPreferredInputDeviceUID(_ uid: String?) {
        guard uid != preferredInputDeviceUID else { return }
        preferredInputDeviceUID = uid
        engine?.preferredInputDeviceUID = uid
        refreshActiveInputDeviceName()

        if isRunning || isStarting {
            restartForInputChange(message: L10n.tr("正在切换音频输入设备…"))
        }
    }

    // MARK: - 输入源变化

    /// 刷新当前输入源名称，供界面常驻显示。
    private func refreshActiveInputDeviceName() {
        #if os(macOS)
        if let uid = preferredInputDeviceUID,
           let device = inputMonitor.devices.first(where: { $0.id == uid }) {
            activeInputDeviceName = device.name
            return
        }

        if preferredInputDeviceUID != nil {
            // 用户指定的设备已经不在了，交给错误横幅说明情况。
            activeInputDeviceName = nil
            return
        }

        if let uid = inputMonitor.defaultDeviceUID,
           let device = inputMonitor.devices.first(where: { $0.id == uid }) {
            activeInputDeviceName = device.name
            return
        }

        activeInputDeviceName = inputMonitor.devices.first(where: \.isDefault)?.name
            ?? AudioInputDevices.all().first(where: \.isDefault)?.name
        #else
        activeInputDeviceName = AudioInputDevices.currentInputName()
        #endif
    }

    /// 系统输入设备列表或默认输入发生变化。
    private func handleInputDevicesChanged() {
        refreshActiveInputDeviceName()

        #if os(macOS)
        if let uid = preferredInputDeviceUID {
            let isStillAvailable = inputMonitor.devices.contains { $0.id == uid }
            guard !isStillAvailable, isRunning || isStarting else { return }

            stop()
            errorText = L10n.tr("之前选择的输入设备已断开，请在设置中重新选择输入设备。")
            statusText = L10n.tr("输入设备已断开")
            return
        }

        let defaultUID = inputMonitor.defaultDeviceUID
        let defaultChanged = defaultUID != lastKnownDefaultInputUID
        lastKnownDefaultInputUID = defaultUID

        // 已经有一次重启在排队时，忽略同一批通知里的重复事件。
        guard inputChangeTask == nil else { return }

        if defaultChanged, isRunning || isStarting {
            restartForInputChange(message: L10n.tr("系统输入设备已切换，正在重新连接…"))
        }
        #endif
    }

    /// 音频引擎报告配置变化，或输入设备被切换时，稍等片刻再重启采集。
    private func restartForInputChange(message: String?) {
        suppressInterruptRestartsUntil = Date().addingTimeInterval(2.0)
        inputChangeTask?.cancel()
        stop()
        errorText = nil
        if let message {
            statusText = message
        }

        inputChangeTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard let self, !Task.isCancelled else { return }
            self.inputChangeTask = nil
            self.startCapture(isAutomatic: true)
        }
    }

    // MARK: - 多音开关

    /// 调音页的「多音调音」开关。
    public func setMultiStringTuningEnabled(_ enabled: Bool) {
        updateDemand(.multiStringTuning, active: enabled)
    }

    /// 和弦识别页出现期间占用多音通道；离开时释放，不影响调音页的开关。
    public func setChordRecognitionActive(_ active: Bool) {
        updateDemand(.chordRecognition, active: active)
    }

    private func updateDemand(_ demand: PolyphonyDemand, active: Bool) {
        var next = polyphonyDemands
        if active {
            next.insert(demand)
        } else {
            next.remove(demand)
        }
        guard next != polyphonyDemands else { return }
        polyphonyDemands = next
        applyPolyphonicEnabled(!next.isEmpty)
    }

    private func applyPolyphonicEnabled(_ enabled: Bool) {
        guard enabled != polyphonicEnabled else { return }

        polyphonicEnabled = enabled
        realtime.polyNotes = []
        realtime.polyReadouts = []
        realtime.polyAnalyzedSeconds = 0
        realtime.polyInferenceMs = 0
        errorText = nil

        guard enabled else {
            isPreparingPoly = false
            engine?.setPolyphonicEnabled(false, maxNotes: maxPolyphony) { _ in }
            if isRunning { statusText = L10n.tr("正在监听…") }
            return
        }

        if let engine, isRunning {
            enablePolyphonic(on: engine)
        } else {
            statusText = L10n.tr("多音识别已选好，点开始调音后生效")
        }
    }

    public func setMaxPolyphony(_ value: Int) {
        let clamped = max(2, min(12, value))
        guard clamped != maxPolyphony else { return }

        maxPolyphony = clamped
        realtime.polyNotes = []
        realtime.polyReadouts = []
        realtime.polyAnalyzedSeconds = 0
        engine?.setPolyphonyLimit(clamped)

        if isRunning, polyphonicEnabled, !isPreparingPoly {
            statusText = L10n.tr("正在监听 · 多音模式（最多 %d 个音）", clamped)
        }
    }

    private func enablePolyphonic(on engine: TunerEngine) {
        isPreparingPoly = true
        statusText = L10n.tr("准备多音模型…")

        engine.setPolyphonicEnabled(true, maxNotes: maxPolyphony) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPreparingPoly = false
                guard self.polyphonicEnabled else { return }

                switch result {
                case .success:
                    if self.isRunning {
                        self.statusText = L10n.tr("正在监听 · 多音模式（最多 %d 个音）", self.maxPolyphony)
                    }
                case .failure(let error):
                    self.polyphonicEnabled = false
                    self.polyphonyDemands = []
                    self.realtime.polyNotes = []
                    self.realtime.polyReadouts = []
                    self.errorText = L10n.tr("多音模型加载失败: %@", error.localizedDescription)
                    self.statusText = L10n.tr("多音识别不可用，已回到单音模式")
                }
            }
        }
    }

    // MARK: - 引擎装配

    private func prepareEngine() async throws -> TunerEngine {
        if let engine { return engine }
        let prepared = try await Task.detached(priority: .userInitiated) { () -> TunerEngine in
            let created = try TunerEngine()
            created.prepare()
            return created
        }.value
        engine = prepared
        return prepared
    }

    private func attachCallbacks(to engine: TunerEngine) {
        engine.onUpdate = { [weak self] update in
            Task { @MainActor [weak self] in
                self?.apply(update)
            }
        }
        engine.onError = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self else { return }

                // 设备插拔、采样率变化都会触发引擎配置变化，重新绑定设备即可恢复，
                // 不需要用户手动重新开始。刚启动后的通知可能是引擎自身产生的，
                // 直接忽略，避免出现反复启停的抖动。
                if let captureError = error as? MicrophoneCaptureError,
                   case .engineInterrupted = captureError,
                   self.isRunning || self.isStarting {
                    guard Date() >= self.suppressInterruptRestartsUntil else { return }

                    let now = Date()
                    self.automaticRestartTimestamps.removeAll {
                        now.timeIntervalSince($0) > 10
                    }
                    guard self.automaticRestartTimestamps.count < 3 else {
                        self.stop()
                        self.errorText = L10n.tr("音频输入反复中断，请重新选择输入设备或重启应用。")
                        self.statusText = L10n.tr("音频输入不稳定")
                        return
                    }
                    self.automaticRestartTimestamps.append(now)
                    self.restartForInputChange(message: L10n.tr("音频输入已变化，正在重新连接…"))
                    return
                }

                self.errorText = error.localizedDescription
                self.statusText = L10n.tr("音频采集中断: %@", error.localizedDescription)
                if self.isRunning {
                    self.stop()
                }
            }
        }
        engine.onPolyUpdate = { [weak self] update in
            Task { @MainActor [weak self] in
                self?.applyPoly(update)
            }
        }
        engine.onPolyError = { [weak self] error in
            Task { @MainActor [weak self] in
                guard let self, self.isRunning, self.polyphonicEnabled else { return }
                self.errorText = L10n.tr("多音识别: %@", error.localizedDescription)
            }
        }
    }

    private func resetRealtimeState() {
        realtime.reset()
        displayMidi = nil
        lastReportedNoteCount = 0
    }

    // MARK: - 状态更新

    private func apply(_ update: TunerUpdate) {
        realtime.analyzedSeconds = update.analyzedSeconds
        realtime.level = realtime.level * 0.6 + update.level * 0.4

        if !update.newFrames.isEmpty {
            realtime.frames.append(contentsOf: update.newFrames)
            // 界面通常只画最近十几秒，但保留 30 秒供切换窗口长度时回看。
            let cutoff = update.analyzedSeconds - 30
            if let index = realtime.frames.firstIndex(where: { $0.time >= cutoff }), index > 0 {
                realtime.frames.removeFirst(index)
            }
        }

        if update.notes != realtime.notes {
            realtime.notes = update.notes
        }
        realtime.liveNote = update.liveNote

        if let latest = update.latestPitch, latest.midi.isFinite {
            let next: Double
            if let previous = displayMidi, abs(latest.midi - previous) < 1.0 {
                next = previous + (latest.midi - previous) * displaySmoothing
            } else {
                next = latest.midi
            }
            displayMidi = next
            realtime.liveMidi = next
            realtime.liveConfidence = latest.confidence
        } else {
            displayMidi = nil
            realtime.liveMidi = nil
            realtime.liveConfidence = 0
        }

        let count = realtime.notes.count + (realtime.liveNote == nil ? 0 : 1)
        if isRunning, !polyphonicEnabled, count != lastReportedNoteCount {
            lastReportedNoteCount = count
            let next = L10n.tr("正在监听 · 已识别 %d 个音", count)
            if statusText != next {
                statusText = next
            }
        }
    }

    private func applyPoly(_ update: TunerPolyUpdate) {
        guard isRunning, polyphonicEnabled else { return }

        realtime.polyAnalyzedSeconds = update.analyzedSeconds
        realtime.polyInferenceMs = update.inferenceMs
        if update.notes != realtime.polyNotes {
            realtime.polyNotes = update.notes
        }

        // 仍然在发声的音：窗口右端受边缘效应影响，留一点余量再判定结束。
        // 同一个音高可能有前后两段（重复拨弦），表盘只保留最靠近现在的一段。
        // 高音在上、低音在下，和钢琴卷帘的排列方向一致。
        let cutoff = update.analyzedSeconds - 0.4
        var latestByPitch: [Int: TunerNote] = [:]
        for note in update.notes where note.endSeconds >= cutoff {
            if let existing = latestByPitch[note.midiPitch] {
                if note.endSeconds > existing.endSeconds {
                    latestByPitch[note.midiPitch] = note
                }
            } else {
                latestByPitch[note.midiPitch] = note
            }
        }
        let readouts = Array(latestByPitch.values
            .sorted { $0.midiPitch > $1.midiPitch }
            .prefix(maxPolyphony)
            .map { TunerPolyReadout(id: $0.id,
                                    midiPitch: $0.midiPitch,
                                    cents: $0.averageCents,
                                    amplitude: $0.amplitude) })
        if readouts != realtime.polyReadouts {
            realtime.polyReadouts = readouts
        }

        let active = min(update.activeNoteCount, maxPolyphony)
        let base = L10n.tr("正在监听 · 多音 %d/%d", active, maxPolyphony)
        let next = update.notes.isEmpty
            ? base
            : L10n.tr("%@ · 已识别 %d 个音", base, update.notes.count)
        // 文本相同就不发布，避免多音通道按窗刷新时反复触发控制器观察者。
        if statusText != next {
            statusText = next
        }
    }
}
