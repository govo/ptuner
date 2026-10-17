//
//  RealtimePolyphonicTracker.swift
//  PTuner
//
//  多音通道：麦克风 22050 Hz 环形缓冲 → Basic Pitch 2 秒滑窗推理 →
//  复音音符事件 → 跨窗合并 → 同时发声数上限。
//
//  与 CREPE 通道的分工：
//  - CREPE 负责 100 ms 级的单音高与音分读数；
//  - 这里只负责「同时有哪些音」。模型输入固定 2 秒，因此本通道天然有
//    约 2 秒的识别延迟，这是模型结构决定的。
//
//  所有时间都以「采集开始」为 0，与 CREPE 通道共用同一个采样时钟。
//

import Foundation

nonisolated final class RealtimePolyphonicTracker: @unchecked Sendable {

    /// 每 0.25 秒重跑一次 2 秒窗。推理慢于该间隔时定时器会自动合并触发。
    static let analysisInterval: TimeInterval = 0.25
    /// 音分只取音符最后这么长的一段，避免整段平均把拨弦后的变化压平。
    static let recentCentsSeconds: TimeInterval = 0.15

    var onUpdate: ((TunerPolyUpdate) -> Void)?
    var onError: ((Error) -> Void)?

    /// 窗口右端受模型边缘效应影响，判定「当前仍发声」时留出的余量。
    private static let edgeGuardSeconds = 0.20
    /// 同音高两段之间小于此值视为同一个音。
    private static let mergeToleranceSeconds = 0.12
    /// 低于此平均激活值的候选直接丢弃，压住弱谐波与噪声。
    private static let minAmplitude: Float = 0.22
    /// 模型 contour 峰值比 `midiToContourBin` 高 1 格，音分必须减掉这一格。
    private static let contourGridOffsetBins = 1

    private let model: BasicPitchModel
    private let analysisQueue = DispatchQueue(label: "ptuner.tuner.polyphonic", qos: .userInitiated)
    private var timer: DispatchSourceTimer?

    // MARK: - 环形缓冲

    private let audioLock = NSLock()
    private var ring: [Float] = []
    private var ringStartIndex = 0
    private var writtenSamples = 0
    /// 留 6 秒：分析只取最新 2 秒，6 秒足够兜底推理变慢时的积压。
    private let maxRingSamples = BasicPitchConstants.sampleRate * 6

    // MARK: - 分析状态（只在 analysisQueue 上访问）

    private var notes: [TunerNote] = []
    private var nextNoteID = 0
    private var maxNotes = 6
    private var lastAnalyzedSeconds: Double = 0
    private var lastInferenceMs: Double = 0

    private struct Candidate {
        let start: Double
        let end: Double
        let midi: Int
        let amplitude: Float
        let cents: Double
    }

    init() throws {
        model = try BasicPitchModel()
    }

    /// 预热模型（首窗包含一次性的图编译）。应在后台线程调用。
    func prepare() {
        model.warmUp()
    }

    // MARK: - 启停

    func start(maxNotes: Int) {
        timer?.cancel()
        timer = nil

        audioLock.lock()
        ring.removeAll(keepingCapacity: true)
        ringStartIndex = 0
        writtenSamples = 0
        audioLock.unlock()

        analysisQueue.sync {
            self.maxNotes = max(2, min(12, maxNotes))
            notes.removeAll()
            nextNoteID = 0
        }

        let source = DispatchSource.makeTimerSource(queue: analysisQueue)
        source.schedule(deadline: .now() + Self.analysisInterval,
                        repeating: Self.analysisInterval,
                        leeway: .milliseconds(20))
        source.setEventHandler { [weak self] in
            self?.tick()
        }
        source.resume()
        timer = source
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    /// 修改复音上限。清空历史重来，让新上限立刻可见。
    func setMaxNotes(_ value: Int) {
        let clamped = max(2, min(12, value))
        analysisQueue.async { [weak self] in
            guard let self else { return }
            self.maxNotes = clamped
            self.notes.removeAll()
            self.nextNoteID = 0
            self.onUpdate?(TunerPolyUpdate(notes: [],
                                           analyzedSeconds: self.lastAnalyzedSeconds,
                                           inferenceMs: self.lastInferenceMs,
                                           activeNoteCount: 0))
        }
    }

    /// 清空已识别音符，但保留音频时间轴。
    func clear() {
        analysisQueue.async { [weak self] in
            guard let self else { return }
            self.notes.removeAll()
            self.nextNoteID = 0
            self.onUpdate?(TunerPolyUpdate(notes: [],
                                           analyzedSeconds: self.lastAnalyzedSeconds,
                                           inferenceMs: self.lastInferenceMs,
                                           activeNoteCount: 0))
        }
    }

    // MARK: - 采集回调

    func append(samples: [Float], at index: Int) {
        guard !samples.isEmpty else { return }
        audioLock.lock()
        if ringStartIndex + ring.count != index {
            // 下标不连续（例如多音通道刚打开）：丢弃旧缓冲，从新下标重新开始。
            ring.removeAll(keepingCapacity: true)
            ringStartIndex = index
        }
        ring.append(contentsOf: samples)
        if ring.count > maxRingSamples {
            let drop = ring.count - maxRingSamples
            ring.removeFirst(drop)
            ringStartIndex += drop
        }
        writtenSamples = ringStartIndex + ring.count
        audioLock.unlock()
    }

    // MARK: - 分析

    private func tick() {
        let needed = BasicPitchConstants.audioNSamples

        audioLock.lock()
        guard writtenSamples >= needed else {
            audioLock.unlock()
            return
        }
        let endIndex = writtenSamples
        let startIndex = endIndex - needed
        let offset = startIndex - ringStartIndex
        guard offset >= 0, offset + needed <= ring.count else {
            audioLock.unlock()
            return
        }
        let window = Array(ring[offset..<(offset + needed)])
        audioLock.unlock()

        let sampleRate = Double(BasicPitchConstants.sampleRate)
        let windowStart = Double(startIndex) / sampleRate
        let windowEnd = Double(endIndex) / sampleRate

        let inferenceStart = CFAbsoluteTimeGetCurrent()
        let output: BasicPitchWindowOutput
        do {
            output = try model.predict(window: window)
        } catch {
            onError?(error)
            return
        }
        let inferenceMs = (CFAbsoluteTimeGetCurrent() - inferenceStart) * 1000.0

        let decoded = BasicPitchNoteDecoder.decode(frames: output.noteFrames,
                                                    onsets: output.onsetFrames,
                                                    contours: output.contourFrames,
                                                    nFrames: output.frames)

        let hopSeconds = Double(BasicPitchConstants.fftHop) / sampleRate
        var candidates: [Candidate] = []
        candidates.reserveCapacity(decoded.count)

        for note in decoded {
            guard note.amplitude >= Self.minAmplitude else { continue }
            let startFrame = max(0, min(note.startFrame, output.frames))
            let endFrame = max(startFrame, min(note.endFrame, output.frames))
            guard endFrame - startFrame >= BasicPitchConstants.minNoteLengthFrames else { continue }

            candidates.append(Candidate(start: windowStart + Double(startFrame) * hopSeconds,
                                        end: windowStart + Double(endFrame) * hopSeconds,
                                        midi: note.midiPitch,
                                        amplitude: note.amplitude,
                                        cents: Self.recentCents(pitchBends: note.continuousPitchBends)))
        }

        // 复音上限只约束「当前仍在发声」的音；已经结束的音作为历史保留，
        // 否则分解和弦里的先后音会被误删。
        let activeCutoff = windowEnd - Self.edgeGuardSeconds - Self.mergeToleranceSeconds
        let ended = candidates.filter { $0.end < activeCutoff }
        let active = candidates
            .filter { $0.end >= activeCutoff }
            .sorted { $0.amplitude > $1.amplitude }
            .prefix(maxNotes)

        var selected = ended + Array(active)
        selected.sort { $0.start < $1.start }

        merge(selected)

        lastAnalyzedSeconds = windowEnd
        lastInferenceMs = inferenceMs

        let activeCount = notes.filter { $0.endSeconds >= windowEnd - Self.edgeGuardSeconds }.count
        onUpdate?(TunerPolyUpdate(notes: notes,
                                  analyzedSeconds: windowEnd,
                                  inferenceMs: inferenceMs,
                                  activeNoteCount: min(activeCount, maxNotes)))
    }

    // MARK: - 跨窗合并

    private func merge(_ candidates: [Candidate]) {
        for candidate in candidates {
            // 同一个 2 秒窗会被反复分析，必须在历史里找到同一个音并把区间并起来。
            // 从后往前找，命中的是同一音高最近的一段，重复拨弦不会被并成一长条。
            if let index = notes.indices.reversed().first(where: { index in
                let note = notes[index]
                return note.midiPitch == candidate.midi
                    && candidate.start <= note.endSeconds + Self.mergeToleranceSeconds
                    && candidate.end >= note.startSeconds - Self.mergeToleranceSeconds
            }) {
                let existing = notes[index]
                let start = min(existing.startSeconds, candidate.start)
                let end = max(existing.endSeconds, candidate.end)

                // 直接用本次窗口的最近音分，而不是和整段历史做时长加权平均。
                // 后者会让持续音在拨弦/推弦后几乎不动，看起来像只判定准或不准。
                notes[index] = TunerNote(id: existing.id,
                                         startSeconds: start,
                                         endSeconds: end,
                                         midiPitch: existing.midiPitch,
                                         averageCents: candidate.cents,
                                         amplitude: max(existing.amplitude, candidate.amplitude))
            } else {
                notes.append(TunerNote(id: nextNoteID,
                                       startSeconds: candidate.start,
                                       endSeconds: candidate.end,
                                       midiPitch: candidate.midi,
                                       averageCents: candidate.cents,
                                       amplitude: candidate.amplitude))
                nextNoteID += 1
            }
        }

        notes.sort { $0.startSeconds < $1.startSeconds }
        // 卷帘最多回看 30 秒，600 个音足够；超出时丢最旧的，避免数组无限增长。
        if notes.count > 600 {
            notes.removeFirst(notes.count - 600)
        }
    }

    // MARK: - 辅助

    /// Basic Pitch 的 contour 每半音 3 格，音高弯曲以 1/3 半音为单位。
    private static func recentCents(pitchBends: [Double]) -> Double {
        guard !pitchBends.isEmpty else { return 0 }

        let hopSeconds = Double(BasicPitchConstants.fftHop) / Double(BasicPitchConstants.sampleRate)
        let frameCount = max(1, Int((recentCentsSeconds / hopSeconds).rounded()))
        let recent = pitchBends.suffix(frameCount)
        let sum = recent.reduce(0, +)
        let meanBins = sum / Double(recent.count) - Double(contourGridOffsetBins)
        return meanBins * (100.0 / Double(BasicPitchConstants.contoursBinsPerSemitone))
    }
}
