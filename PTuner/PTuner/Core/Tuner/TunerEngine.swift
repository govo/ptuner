//
//  TunerEngine.swift
//  PTuner
//
//  实时调音器的核心：麦克风 → 16 kHz 环形缓冲 → CREPE 逐帧推理 → 音高/音符。
//
//  为什么用 CREPE 而不是 Basic Pitch 做单音：
//  Basic Pitch 的模型输入固定为 2 秒（43844 采样 @22050），滑窗推理延迟至少
//  2 秒，且输出只有半音精度；调音器需要 100 ms 级反馈和音分读数。
//  CREPE 的输入是 1024 采样 @16 kHz（64 ms 窗）、hop 160（10 ms），
//  可以按 50 ms 一批做流式推理，延迟约 100 ms，且天然输出连续音高。
//
//  线程模型：
//  - 采集回调在自己的音频线程，只做「加锁写环形缓冲」；
//  - 分析定时器在独立串行队列上跑 CREPE，通过 onUpdate 推给上层；
//  - 上层负责切回主线程更新界面。
//

import Foundation

nonisolated final class TunerEngine: @unchecked Sendable {

    /// 每批推理结果。回调发生在内部的分析队列上。
    var onUpdate: ((TunerUpdate) -> Void)?
    var onError: ((Error) -> Void)?
    /// 多音通道的结果/错误。多音通道出错不应中断单音调音通道。
    var onPolyUpdate: ((TunerPolyUpdate) -> Void)?
    var onPolyError: ((Error) -> Void)?

    private let capture = MicrophoneAudioCapture()
    private let model: CrepeModel
    private let analysisQueue = DispatchQueue(label: "ptuner.tuner.analysis", qos: .userInteractive)
    private var timer: DispatchSourceTimer?

    // MARK: - 多音通道（Basic Pitch 滑窗）

    private let polyLock = NSLock()
    private var polyTracker: RealtimePolyphonicTracker?
    private var polyDesired = false
    private var polyLimit = 6
    /// 模型加载 + 预热是重操作，放在独立串行队列，避免阻塞 CREPE 分析。
    private let polySetupQueue = DispatchQueue(label: "ptuner.tuner.polyphonic.setup", qos: .userInitiated)

    // MARK: - 音频环形缓冲

    private let audioLock = NSLock()
    private var ring: [Float] = []
    /// ring[0] 在整段录音里的绝对下标。
    private var ringStartIndex = 0
    private var writtenSamples = 0
    /// 最多保留 4 秒音频。分析最多只落后 1 秒，4 秒足够兜底。
    private let maxRingSamples = CrepeConstants.sampleRate * 4

    // MARK: - 分析状态（只在 analysisQueue 上访问）

    private var nextCenter = CrepeConstants.windowSize / 2
    private var notes: [TunerNote] = []
    private var openNote: OpenNote?
    private var nextNoteID = 0
    /// 最近几帧的原始音高，做 3 帧中值平滑，压住半音边界上的抖动。
    private var recentMidi: [Double] = []
    private var lastVoicedPitch: TunerPitchFrame?
    private var lastTime: Double = 0

    // MARK: - 参数

    private let onsetThreshold = CrepeConstants.defaultConfidenceThreshold
    private let releaseThreshold = max(0, CrepeConstants.defaultConfidenceThreshold - CrepeConstants.hysteresisMargin)
    /// 低于此 RMS 视为静音。CREPE 对纯噪声也会给出一个「音高」，必须用它挡住。
    private let minRMS: Float = 0.0015
    private let minNoteSeconds = 0.04
    /// 短于此时长的断音不立刻收尾，避免一个音被切成碎片。
    private let bridgeSilenceSeconds = 0.06
    private let mergeGapSeconds = 0.06
    /// 单次定时器最多处理 12 帧（120 ms），防止推理落后时一次积压太多。
    private let maxFramesPerTick = 12
    /// 允许的最大分析滞后。超过就主动丢旧音频，保证实时性。
    private let maxBacklogSeconds = 1.0
    private let frameDuration = Double(CrepeConstants.hopLength) / Double(CrepeConstants.sampleRate)

    private struct OpenNote {
        let id: Int
        let midi: Int
        let start: Double
        var lastVoiced: Double
        var centsSum: Double
        var confidenceSum: Float
        var frameCount: Int
    }

    // MARK: - 初始化

    init() throws {
        model = try CrepeModel()
    }

    /// 预热模型（首帧包含一次性的图编译）。应在后台线程调用。
    func prepare() {
        model.warmUp()
    }

    // MARK: - 启停

    func start() throws {
        audioLock.lock()
        ring.removeAll(keepingCapacity: true)
        ringStartIndex = 0
        writtenSamples = 0
        audioLock.unlock()

        analysisQueue.sync {
            notes.removeAll()
            openNote = nil
            nextNoteID = 0
            recentMidi.removeAll()
            lastVoicedPitch = nil
            lastTime = 0
            nextCenter = CrepeConstants.windowSize / 2
        }

        capture.onSamples = { [weak self] samples, index in
            self?.append(samples: samples, at: index)
        }
        capture.onPolySamples = { [weak self] samples, index in
            guard let self else { return }
            self.polyLock.lock()
            let tracker = self.polyTracker
            self.polyLock.unlock()
            tracker?.append(samples: samples, at: index)
        }
        capture.onError = { [weak self] error in
            self?.onError?(error)
        }

        // 上一次会话的多音追踪器如果停在中间，重新开始前先停掉；
        // 真正的重启由上层在 start 成功后按开关状态调用 setPolyphonicEnabled 完成。
        polyLock.lock()
        let existingTracker = polyTracker
        polyLock.unlock()
        existingTracker?.stop()

        try capture.start()
        startAnalysisTimer()
    }

    func stop() {
        timer?.cancel()
        timer = nil

        polyLock.lock()
        polyDesired = false
        let tracker = polyTracker
        polyLock.unlock()
        capture.setPolyphonicCaptureEnabled(false)
        tracker?.stop()

        capture.stop()

        analysisQueue.sync {
            // 停止时把正在发声的音符收尾，保证卷帘上的最后一块是完整的。
            finalizeOpenNote()
            lastVoicedPitch = nil
            let update = TunerUpdate(newFrames: [],
                                     notes: notes,
                                     liveNote: nil,
                                     latestPitch: nil,
                                     level: 0,
                                     analyzedSeconds: lastTime)
            onUpdate?(update)
        }
    }

    /// 清空本次记录的音符与平滑状态，但保持录音时间轴继续滚动。
    func clearNotes() {
        analysisQueue.async { [weak self] in
            guard let self else { return }
            self.openNote = nil
            self.notes.removeAll()
            self.recentMidi.removeAll()
            self.lastVoicedPitch = nil
            self.onUpdate?(TunerUpdate(newFrames: [],
                                       notes: [],
                                       liveNote: nil,
                                       latestPitch: nil,
                                       level: 0,
                                       analyzedSeconds: self.lastTime))
        }

        polyLock.lock()
        let tracker = polyTracker
        polyLock.unlock()
        tracker?.clear()
    }

    // MARK: - 多音通道

    /// 打开/关闭 Basic Pitch 多音识别。
    ///
    /// 首次打开会在后台创建并预热模型（需要数秒），完成后回调。
    /// 回调可能在任意队列上执行，上层负责切回主线程。
    func setPolyphonicEnabled(_ enabled: Bool,
                              maxNotes: Int,
                              completion: @escaping (Result<Void, Error>) -> Void) {
        let limit = max(2, min(12, maxNotes))

        polyLock.lock()
        polyDesired = enabled
        polyLimit = limit
        let existing = polyTracker
        polyLock.unlock()

        guard enabled else {
            capture.setPolyphonicCaptureEnabled(false)
            existing?.stop()
            completion(.success(()))
            return
        }

        if let existing {
            existing.start(maxNotes: limit)
            capture.setPolyphonicCaptureEnabled(true)
            completion(.success(()))
            return
        }

        polySetupQueue.async { [weak self] in
            guard let self else { return }

            // 排队期间可能已经被另一次打开准备好了，直接复用。
            self.polyLock.lock()
            let wanted = self.polyDesired
            let ready = self.polyTracker
            let currentLimit = self.polyLimit
            self.polyLock.unlock()

            if let ready {
                if wanted {
                    ready.start(maxNotes: currentLimit)
                    self.capture.setPolyphonicCaptureEnabled(true)
                }
                completion(.success(()))
                return
            }
            guard wanted else {
                completion(.success(()))
                return
            }

            do {
                let tracker = try RealtimePolyphonicTracker()
                tracker.onUpdate = { [weak self] update in
                    self?.onPolyUpdate?(update)
                }
                tracker.onError = { [weak self] error in
                    self?.onPolyError?(error)
                }
                tracker.prepare()

                self.polyLock.lock()
                self.polyTracker = tracker
                let stillWanted = self.polyDesired
                let limitNow = self.polyLimit
                self.polyLock.unlock()

                if stillWanted {
                    tracker.start(maxNotes: limitNow)
                    self.capture.setPolyphonicCaptureEnabled(true)
                } else {
                    tracker.stop()
                }
                completion(.success(()))
            } catch {
                completion(.failure(error))
            }
        }
    }

    /// 修改同时识别的最大音数（2 ~ 12）。追踪器会清空历史并按新上限重来。
    func setPolyphonyLimit(_ maxNotes: Int) {
        let limit = max(2, min(12, maxNotes))
        polyLock.lock()
        polyLimit = limit
        let tracker = polyTracker
        let desired = polyDesired
        polyLock.unlock()

        capture.setPolyphonicCaptureEnabled(desired && tracker != nil)
        tracker?.setMaxNotes(limit)
    }

    // MARK: - 采集回调

    private func append(samples: [Float], at index: Int) {
        guard !samples.isEmpty else { return }
        audioLock.lock()
        if ringStartIndex + ring.count != index {
            // 采样下标不连续（路由切换等）：丢弃旧缓冲，从新下标重新开始。
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

    // MARK: - 分析循环

    private func startAnalysisTimer() {
        let source = DispatchSource.makeTimerSource(queue: analysisQueue)
        // 50 ms 一拍：每拍覆盖约 5 帧（50 ms 音频），与推理速度留出余量。
        source.schedule(deadline: .now() + .milliseconds(50),
                        repeating: .milliseconds(50),
                        leeway: .milliseconds(10))
        source.setEventHandler { [weak self] in
            self?.tick()
        }
        source.resume()
        timer = source
    }

    private func tick() {
        var frames: [TunerPitchFrame] = []

        audioLock.lock()
        // 最新可分析帧的窗尾不能超过已写入的样本。
        let newestCenter = writtenSamples - CrepeConstants.windowSize / 2
        if newestCenter >= nextCenter {
            let backlog = newestCenter - nextCenter
            if backlog > Int(maxBacklogSeconds * Double(CrepeConstants.sampleRate)) {
                nextCenter = newestCenter - Int(maxBacklogSeconds * Double(CrepeConstants.sampleRate))
            }

            var batch: [Float] = []
            var centers: [Int] = []
            var levels: [Float] = []

            while nextCenter <= newestCenter && centers.count < maxFramesPerTick {
                let start = nextCenter - CrepeConstants.windowSize / 2
                let offset = start - ringStartIndex
                guard offset >= 0, offset + CrepeConstants.windowSize <= ring.count else { break }

                var level: Float = 0
                appendNormalizedFrame(into: &batch, offset: offset, level: &level)
                centers.append(nextCenter)
                levels.append(level)
                nextCenter += CrepeConstants.hopLength
            }
            audioLock.unlock()

            if !centers.isEmpty {
                do {
                    let activations = try model.predict(frames: batch, frameCount: centers.count)
                    frames = decode(activations: activations, centers: centers, levels: levels)
                } catch {
                    onError?(error)
                    return
                }
            }
        } else {
            audioLock.unlock()
        }

        let update = ingest(frames)
        if let update {
            onUpdate?(update)
        }
    }

    /// 与 CrepeTranscriber 一致的逐帧预处理：帧内减均值、除以样本标准差。
    private func appendNormalizedFrame(into batch: inout [Float], offset: Int, level: inout Float) {
        let window = CrepeConstants.windowSize
        var sum = 0.0
        for index in 0..<window {
            sum += Double(ring[offset + index])
        }
        let mean = sum / Double(window)

        var squareSum = 0.0
        for index in 0..<window {
            let delta = Double(ring[offset + index]) - mean
            squareSum += delta * delta
        }
        let standardDeviation = (squareSum / Double(window - 1)).squareRoot()
        let scale = 1.0 / max(1e-10, standardDeviation)
        level = Float((squareSum / Double(window)).squareRoot())

        let base = batch.count
        batch.append(contentsOf: repeatElement(0, count: window))
        for index in 0..<window {
            batch[base + index] = Float((Double(ring[offset + index]) - mean) * scale)
        }
    }

    private func decode(activations: [Float],
                        centers: [Int],
                        levels: [Float]) -> [TunerPitchFrame] {
        let bins = CrepeConstants.pitchBins
        var frames: [TunerPitchFrame] = []
        frames.reserveCapacity(centers.count)

        for index in 0..<centers.count {
            let decoded = CrepePitchDecoder.localAverageCents(activations: activations,
                                                              base: index * bins)
            let midi = CrepeConstants.centsToMidi(decoded.cents)
            let level = levels[index]
            let isSilent = level < minRMS || !midi.isFinite
            frames.append(TunerPitchFrame(time: Double(centers[index]) / MicrophoneAudioCapture.targetSampleRate,
                                          midi: midi,
                                          confidence: isSilent ? 0 : decoded.confidence,
                                          level: level))
        }
        return frames
    }

    // MARK: - 音符切分

    private func ingest(_ frames: [TunerPitchFrame]) -> TunerUpdate? {
        guard !frames.isEmpty else { return nil }

        var smoothedFrames: [TunerPitchFrame] = []
        smoothedFrames.reserveCapacity(frames.count)

        for raw in frames {
            lastTime = raw.time

            if raw.level < minRMS {
                recentMidi.removeAll(keepingCapacity: true)
            } else if raw.confidence >= releaseThreshold, raw.midi.isFinite {
                recentMidi.append(raw.midi)
                if recentMidi.count > 3 { recentMidi.removeFirst() }
            }

            let threshold = openNote == nil ? onsetThreshold : releaseThreshold
            let voiced = raw.level >= minRMS
                && raw.confidence >= threshold
                && !recentMidi.isEmpty

            guard voiced else {
                smoothedFrames.append(raw)
                if let open = openNote, raw.time - open.lastVoiced > bridgeSilenceSeconds {
                    finalizeOpenNote()
                }
                continue
            }

            let smoothed = median(recentMidi)
            let frame = TunerPitchFrame(time: raw.time,
                                        midi: smoothed,
                                        confidence: raw.confidence,
                                        level: raw.level)
            smoothedFrames.append(frame)

            let semitone = Int(smoothed.rounded())
            let cents = (smoothed - Double(semitone)) * 100

            if let open = openNote {
                if open.midi == semitone {
                    var updated = open
                    updated.lastVoiced = frame.time + frameDuration
                    updated.centsSum += cents
                    updated.confidenceSum += frame.confidence
                    updated.frameCount += 1
                    openNote = updated
                } else {
                    finalizeOpenNote()
                    startNote(semitone, frame: frame, cents: cents)
                }
            } else {
                startNote(semitone, frame: frame, cents: cents)
            }

            lastVoicedPitch = frame
        }

        return TunerUpdate(newFrames: smoothedFrames,
                           notes: notes,
                           liveNote: openNoteSnapshot(),
                           latestPitch: openNote == nil ? nil : lastVoicedPitch,
                           level: frames.map(\.level).max() ?? 0,
                           analyzedSeconds: lastTime)
    }

    private func startNote(_ midi: Int, frame: TunerPitchFrame, cents: Double) {
        openNote = OpenNote(id: nextNoteID,
                            midi: midi,
                            start: frame.time,
                            lastVoiced: frame.time + frameDuration,
                            centsSum: cents,
                            confidenceSum: frame.confidence,
                            frameCount: 1)
        nextNoteID += 1
    }

    private func finalizeOpenNote() {
        guard let open = openNote else { return }
        openNote = nil
        lastVoicedPitch = nil

        let duration = open.lastVoiced - open.start
        guard duration >= minNoteSeconds else { return }

        let cents = open.centsSum / Double(max(1, open.frameCount))
        let amplitude = open.confidenceSum / Float(max(1, open.frameCount))
        let note = TunerNote(id: open.id,
                             startSeconds: open.start,
                             endSeconds: open.lastVoiced,
                             midiPitch: open.midi,
                             averageCents: cents,
                             amplitude: amplitude)

        // 同音高、间隔很近的两段并成一个音，补上抖动造成的缝。
        if let last = notes.last,
           last.midiPitch == note.midiPitch,
           note.startSeconds - last.endSeconds <= mergeGapSeconds {
            let total = last.durationSeconds + note.durationSeconds
            let mergedCents = total > 0
                ? (last.averageCents * last.durationSeconds + note.averageCents * note.durationSeconds) / total
                : note.averageCents
            notes[notes.count - 1] = TunerNote(id: last.id,
                                               startSeconds: last.startSeconds,
                                               endSeconds: max(last.endSeconds, note.endSeconds),
                                               midiPitch: last.midiPitch,
                                               averageCents: mergedCents,
                                               amplitude: max(last.amplitude, note.amplitude))
        } else {
            notes.append(note)
        }
    }

    private func openNoteSnapshot() -> TunerNote? {
        guard let open = openNote else { return nil }
        return TunerNote(id: open.id,
                         startSeconds: open.start,
                         endSeconds: open.lastVoiced,
                         midiPitch: open.midi,
                         averageCents: open.centsSum / Double(max(1, open.frameCount)),
                         amplitude: open.confidenceSum / Float(max(1, open.frameCount)))
    }

    private func median(_ values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        let sorted = values.sorted()
        return sorted[sorted.count / 2]
    }
}
