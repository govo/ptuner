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
    @Published public private(set) var statusText = "点击开始，允许麦克风后即可实时调音"
    @Published public private(set) var permissionDenied = false
    @Published public private(set) var errorText: String?

    // MARK: - 实时结果（CREPE 单音通道）

    @Published public private(set) var notes: [TunerNote] = []
    @Published public private(set) var liveNote: TunerNote?
    /// 平滑后的连续 MIDI 音高；nil 表示当前没有可用的发声。
    @Published public private(set) var liveMidi: Double?
    @Published public private(set) var liveConfidence: Float = 0
    @Published public private(set) var level: Float = 0
    /// 最近 30 秒的逐帧音高，供音高曲线使用。
    @Published public private(set) var frames: [TunerPitchFrame] = []
    @Published public private(set) var analyzedSeconds: Double = 0

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
    @Published public private(set) var polyNotes: [TunerNote] = []
    /// 当前同时发声的每个音各一行音准读数，最多 maxPolyphony 行。
    @Published public private(set) var polyReadouts: [TunerPolyReadout] = []
    @Published public private(set) var polyAnalyzedSeconds: Double = 0
    @Published public private(set) var polyInferenceMs: Double = 0
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

    // MARK: - 派生读数

    public var liveNearestMidi: Int? {
        guard let midi = liveMidi, midi.isFinite else { return nil }
        return Int(midi.rounded())
    }

    public var liveNoteName: String? {
        liveNearestMidi.map { BasicPitchConstants.noteName(midi: $0) }
    }

    public var liveFrequency: Double? {
        guard let midi = liveMidi, midi.isFinite else { return nil }
        return 440.0 * pow(2.0, (midi - 69.0) / 12.0)
    }

    /// 相对最近十二平均律音高的偏差（音分，-50 ~ +50）。
    public var liveCents: Double? {
        guard let midi = liveMidi, midi.isFinite else { return nil }
        return (midi - midi.rounded()) * 100
    }

    public var liveStatusText: String {
        guard let cents = liveCents else { return "等待声音" }
        if abs(cents) <= 5 { return "准" }
        return cents < 0 ? "偏低" : "偏高"
    }

    /// 当前模式下应展示的音符：多音模式用 Basic Pitch 的结果，单音模式用 CREPE。
    public var activeNotes: [TunerNote] {
        polyphonicEnabled ? polyNotes : notes
    }

    /// 多音模式下不再叠加单音的「正在发声」块，避免同一个音重复画两次。
    public var activeLiveNote: TunerNote? {
        polyphonicEnabled ? nil : liveNote
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
        statusText = "请求麦克风权限…"

        startTask?.cancel()
        startTask = Task { [weak self] in
            guard let self else { return }

            let granted = await MicrophoneAudioCapture.requestPermission()
            guard !Task.isCancelled else { return }
            guard granted else {
                self.isStarting = false
                self.permissionDenied = true
                self.statusText = "没有麦克风权限"
                return
            }

            self.statusText = "加载音高模型…"

            do {
                let prepared = try await self.prepareEngine()
                guard !Task.isCancelled else { return }

                self.attachCallbacks(to: prepared)
                self.statusText = "启动麦克风…"
                self.resetRealtimeState()
                prepared.preferredInputDeviceUID = self.preferredInputDeviceUID

                try prepared.start()

                self.isRunning = true
                self.isStarting = false
                self.suppressInterruptRestartsUntil = Date().addingTimeInterval(2.0)
                self.refreshActiveInputDeviceName()
                self.statusText = "正在监听…"

                if self.polyphonicEnabled {
                    self.enablePolyphonic(on: prepared)
                }
            } catch {
                self.isStarting = false
                self.isRunning = false
                self.isPreparingPoly = false
                self.errorText = error.localizedDescription
                self.statusText = "启动失败: \(error.localizedDescription)"
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
        liveMidi = nil
        displayMidi = nil
        liveNote = nil
        level = 0
        // 停止后不再有「正在发声」的音，表盘清空；历史音块保留。
        polyReadouts = []

        if polyphonicEnabled {
            statusText = polyNotes.isEmpty ? "已停止 · 多音识别已关闭" : "已停止 · 多音识别共 \(polyNotes.count) 个音"
        } else {
            statusText = notes.isEmpty ? "已停止" : "已停止 · 本次识别 \(notes.count) 个音"
        }
    }

    /// 清空音符与曲线；运行中保持音频时间轴继续滚动。
    public func clear() {
        engine?.clearNotes()
        notes = []
        polyNotes = []
        polyReadouts = []
        polyAnalyzedSeconds = 0
        polyInferenceMs = 0
        liveNote = nil
        frames = []
        liveMidi = nil
        displayMidi = nil
        level = 0
        analyzedSeconds = 0
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
            restartForInputChange(message: "正在切换音频输入设备…")
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
            errorText = "之前选择的输入设备已断开，请在设置中重新选择输入设备。"
            statusText = "输入设备已断开"
            return
        }

        let defaultUID = inputMonitor.defaultDeviceUID
        let defaultChanged = defaultUID != lastKnownDefaultInputUID
        lastKnownDefaultInputUID = defaultUID

        // 已经有一次重启在排队时，忽略同一批通知里的重复事件。
        guard inputChangeTask == nil else { return }

        if defaultChanged, isRunning || isStarting {
            restartForInputChange(message: "系统输入设备已切换，正在重新连接…")
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
        polyNotes = []
        polyReadouts = []
        polyAnalyzedSeconds = 0
        polyInferenceMs = 0
        errorText = nil

        guard enabled else {
            isPreparingPoly = false
            engine?.setPolyphonicEnabled(false, maxNotes: maxPolyphony) { _ in }
            if isRunning { statusText = "正在监听…" }
            return
        }

        if let engine, isRunning {
            enablePolyphonic(on: engine)
        } else {
            statusText = "多音识别已选好，点开始调音后生效"
        }
    }

    public func setMaxPolyphony(_ value: Int) {
        let clamped = max(2, min(12, value))
        guard clamped != maxPolyphony else { return }

        maxPolyphony = clamped
        polyNotes = []
        polyReadouts = []
        polyAnalyzedSeconds = 0
        engine?.setPolyphonyLimit(clamped)

        if isRunning, polyphonicEnabled, !isPreparingPoly {
            statusText = "正在监听 · 多音模式（最多 \(clamped) 个音）"
        }
    }

    private func enablePolyphonic(on engine: TunerEngine) {
        isPreparingPoly = true
        statusText = "准备多音模型…"

        engine.setPolyphonicEnabled(true, maxNotes: maxPolyphony) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPreparingPoly = false
                guard self.polyphonicEnabled else { return }

                switch result {
                case .success:
                    if self.isRunning {
                        self.statusText = "正在监听 · 多音模式（最多 \(self.maxPolyphony) 个音）"
                    }
                case .failure(let error):
                    self.polyphonicEnabled = false
                    self.polyphonyDemands = []
                    self.polyNotes = []
                    self.polyReadouts = []
                    self.errorText = "多音模型加载失败: \(error.localizedDescription)"
                    self.statusText = "多音识别不可用，已回到单音模式"
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
                        self.errorText = "音频输入反复中断，请重新选择输入设备或重启应用。"
                        self.statusText = "音频输入不稳定"
                        return
                    }
                    self.automaticRestartTimestamps.append(now)
                    self.restartForInputChange(message: "音频输入已变化，正在重新连接…")
                    return
                }

                self.errorText = error.localizedDescription
                self.statusText = "音频采集中断: \(error.localizedDescription)"
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
                self.errorText = "多音识别: \(error.localizedDescription)"
            }
        }
    }

    private func resetRealtimeState() {
        notes = []
        liveNote = nil
        frames = []
        liveMidi = nil
        displayMidi = nil
        level = 0
        analyzedSeconds = 0
        lastReportedNoteCount = 0
        polyNotes = []
        polyReadouts = []
        polyAnalyzedSeconds = 0
        polyInferenceMs = 0
    }

    // MARK: - 状态更新

    private func apply(_ update: TunerUpdate) {
        analyzedSeconds = update.analyzedSeconds
        level = level * 0.6 + update.level * 0.4

        if !update.newFrames.isEmpty {
            frames.append(contentsOf: update.newFrames)
            // 界面通常只画最近十几秒，但保留 30 秒供切换窗口长度时回看。
            let cutoff = update.analyzedSeconds - 30
            if let index = frames.firstIndex(where: { $0.time >= cutoff }), index > 0 {
                frames.removeFirst(index)
            }
        }

        if update.notes != notes {
            notes = update.notes
        }
        liveNote = update.liveNote

        if let latest = update.latestPitch, latest.midi.isFinite {
            let next: Double
            if let previous = displayMidi, abs(latest.midi - previous) < 1.0 {
                next = previous + (latest.midi - previous) * displaySmoothing
            } else {
                next = latest.midi
            }
            displayMidi = next
            liveMidi = next
            liveConfidence = latest.confidence
        } else {
            displayMidi = nil
            liveMidi = nil
            liveConfidence = 0
        }

        let count = notes.count + (liveNote == nil ? 0 : 1)
        if isRunning, !polyphonicEnabled, count != lastReportedNoteCount {
            lastReportedNoteCount = count
            statusText = "正在监听 · 已识别 \(count) 个音"
        }
    }

    private func applyPoly(_ update: TunerPolyUpdate) {
        guard isRunning, polyphonicEnabled else { return }

        polyAnalyzedSeconds = update.analyzedSeconds
        polyInferenceMs = update.inferenceMs
        if update.notes != polyNotes {
            polyNotes = update.notes
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
        if readouts != polyReadouts {
            polyReadouts = readouts
        }

        let active = min(update.activeNoteCount, maxPolyphony)
        let base = "正在监听 · 多音 \(active)/\(maxPolyphony)"
        statusText = update.notes.isEmpty ? base : "\(base) · 已识别 \(update.notes.count) 个音"
    }
}
