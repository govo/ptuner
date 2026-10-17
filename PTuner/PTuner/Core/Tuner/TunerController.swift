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
    /// 同时识别的最大音数（2 ~ 12）。
    @Published public private(set) var maxPolyphony = 6
    @Published public private(set) var polyNotes: [TunerNote] = []
    /// 当前同时发声的每个音各一行音准读数，最多 maxPolyphony 行。
    @Published public private(set) var polyReadouts: [TunerPolyReadout] = []
    @Published public private(set) var polyAnalyzedSeconds: Double = 0
    @Published public private(set) var polyInferenceMs: Double = 0
    @Published public private(set) var isPreparingPoly = false

    private var engine: TunerEngine?
    private var startTask: Task<Void, Never>?
    private var displayMidi: Double?
    private var lastReportedNoteCount = 0

    public init() {}

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
        guard !isRunning, !isStarting else { return }

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

                try prepared.start()

                self.isRunning = true
                self.isStarting = false
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

    // MARK: - 多音开关

    public func setPolyphonicEnabled(_ enabled: Bool) {
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
                next = previous + (latest.midi - previous) * 0.35
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
