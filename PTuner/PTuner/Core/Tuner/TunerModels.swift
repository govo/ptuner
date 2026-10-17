//
//  TunerModels.swift
//  PTuner
//
//  实时调音器的数据模型。
//
//  调音器是一边听一边产出，所以音符用可变时长（正在发声的音符 endSeconds
//  会随后续帧推进），并额外保留逐帧的连续音高，用来画实时音高曲线。
//

import Foundation

/// CREPE 的一帧解码结果。time 以本次录音开始为 0。
nonisolated public struct TunerPitchFrame: Equatable, Sendable {
    public let time: Double
    /// 连续 MIDI 音高（可为小数），已做 3 帧中值平滑。
    public let midi: Double
    /// CREPE 置信度。0 表示这一帧判为未发声。
    public let confidence: Float
    /// 该帧音频的 RMS（0 ~ 1），用于判断是否真的在发声。
    public let level: Float

    public init(time: Double, midi: Double, confidence: Float, level: Float) {
        self.time = time
        self.midi = midi
        self.confidence = confidence
        self.level = level
    }

    public var isVoiced: Bool { confidence > 0 && midi.isFinite }

    public var frequency: Double {
        guard midi.isFinite else { return 0 }
        return 440.0 * pow(2.0, (midi - 69.0) / 12.0)
    }

    public var nearestMidi: Int { Int(midi.rounded()) }

    /// 相对最近十二平均律音高的偏差，单位音分（-50 ~ +50）。
    public var cents: Double {
        guard midi.isFinite else { return 0 }
        return (midi - midi.rounded()) * 100.0
    }

    public var noteName: String { BasicPitchConstants.noteName(midi: nearestMidi) }
}

/// 调音器切分出的一个音符块。
nonisolated public struct TunerNote: Identifiable, Equatable, Sendable {
    public let id: Int
    public let startSeconds: Double
    public let endSeconds: Double
    public let midiPitch: Int
    /// 音符区间内的平均音分偏差。调音器用它给音块上色（准 / 偏高 / 偏低）。
    public let averageCents: Double
    /// 平均置信度（0 ~ 1），决定音块透明度。
    public let amplitude: Float

    public init(id: Int,
                startSeconds: Double,
                endSeconds: Double,
                midiPitch: Int,
                averageCents: Double,
                amplitude: Float) {
        self.id = id
        self.startSeconds = startSeconds
        self.endSeconds = endSeconds
        self.midiPitch = midiPitch
        self.averageCents = averageCents
        self.amplitude = amplitude
    }

    public var noteName: String { BasicPitchConstants.noteName(midi: midiPitch) }
    public var durationSeconds: Double { max(0, endSeconds - startSeconds) }
    public var isInTune: Bool { abs(averageCents) <= 10 }
}

/// 多音模式下，每个正在发声的音对应的一行音准读数。
nonisolated public struct TunerPolyReadout: Identifiable, Equatable, Sendable {
    /// 复用 TunerNote.id：同一个音跨窗合并时 id 不变，列表不会整行闪烁。
    public let id: Int
    public let midiPitch: Int
    /// 相对十二平均律该半音的音分偏差。
    public let cents: Double
    public let amplitude: Float

    public init(id: Int, midiPitch: Int, cents: Double, amplitude: Float) {
        self.id = id
        self.midiPitch = midiPitch
        self.cents = cents
        self.amplitude = amplitude
    }

    public var noteName: String { BasicPitchConstants.noteName(midi: midiPitch) }

    /// 把音分偏差算进频率，读数比只显示半音更贴近实际听到的音高。
    public var frequency: Double {
        440.0 * pow(2.0, (Double(midiPitch) + cents / 100.0 - 69.0) / 12.0)
    }

    public var statusText: String {
        if abs(cents) <= 5 { return L10n.tr("准") }
        return cents < 0 ? L10n.tr("偏低") : L10n.tr("偏高")
    }
}

/// Basic Pitch 多音通道的一次滑窗结果。
nonisolated public struct TunerPolyUpdate: Sendable {
    /// 到目前为止识别出的全部多音音符（已跨窗合并）。
    public let notes: [TunerNote]
    /// 本窗分析到的音频末端时间（秒）。
    public let analyzedSeconds: Double
    /// 本窗推理耗时（毫秒）。
    public let inferenceMs: Double
    /// 当前仍在发声的音符数（已按复音上限过滤）。
    public let activeNoteCount: Int

    public init(notes: [TunerNote],
                analyzedSeconds: Double,
                inferenceMs: Double,
                activeNoteCount: Int) {
        self.notes = notes
        self.analyzedSeconds = analyzedSeconds
        self.inferenceMs = inferenceMs
        self.activeNoteCount = activeNoteCount
    }
}

/// 分析线程每次向界面推送的一批增量。
nonisolated public struct TunerUpdate: Sendable {
    /// 本次新增的逐帧音高。
    public let newFrames: [TunerPitchFrame]
    /// 已完成切分的全部音符（含合并后的结果）。
    public let notes: [TunerNote]
    /// 正在发声、尚未收尾的音符。
    public let liveNote: TunerNote?
    /// 当前用于音准指针的帧（平滑后的音高）。静音时为 nil。
    public let latestPitch: TunerPitchFrame?
    /// 最近一帧的输入电平（RMS）。
    public let level: Float
    /// 已分析到的音频时间（秒）。
    public let analyzedSeconds: Double

    public init(newFrames: [TunerPitchFrame],
                notes: [TunerNote],
                liveNote: TunerNote?,
                latestPitch: TunerPitchFrame?,
                level: Float,
                analyzedSeconds: Double) {
        self.newFrames = newFrames
        self.notes = notes
        self.liveNote = liveNote
        self.latestPitch = latestPitch
        self.level = level
        self.analyzedSeconds = analyzedSeconds
    }
}
