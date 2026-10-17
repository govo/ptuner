import Foundation

// MARK: - 音准状态

nonisolated enum TuningStatus: String, Sendable, Equatable {
    case idle
    case inTune
    case low
    case high
    case veryLow
    case veryHigh

    static func from(cents: Double) -> TuningStatus {
        let magnitude = abs(cents)
        if magnitude <= 5 { return .inTune }
        if magnitude <= 20 { return cents < 0 ? .low : .high }
        return cents < 0 ? .veryLow : .veryHigh
    }

    var isInTune: Bool { self == .inTune }

    var isFlat: Bool { self == .low || self == .veryLow }

    var isSharp: Bool { self == .high || self == .veryHigh }

    var directionText: String {
        switch self {
        case .idle: return "等待声音"
        case .inTune: return "音准准确"
        case .low: return "音准偏低"
        case .high: return "音准偏高"
        case .veryLow: return "明显偏低"
        case .veryHigh: return "明显偏高"
        }
    }

    var shortText: String {
        switch self {
        case .idle: return "—"
        case .inTune: return "准"
        case .low: return "偏低"
        case .high: return "偏高"
        case .veryLow: return "偏低"
        case .veryHigh: return "偏高"
        }
    }
}

// MARK: - 单音读数

nonisolated struct TuningReading: Equatable, Sendable {
    let rawMidi: Double
    let adjustedMidi: Double
    let frequency: Double
    let noteName: String
    /// 相对目标音的偏差（音分）。
    let cents: Double
    /// 命中的弦在配置中的下标；半音阶调音或未命中时为 nil。
    let matchedStringIndex: Int?
    let targetDisplayName: String?

    var status: TuningStatus { TuningStatus.from(cents: cents) }

    /// - Parameters:
    ///   - rawMidi: CREPE 输出的 MIDI（按 A4 = 440 计算）。
    ///   - referencePitch: 用户设置的 A4 参考频率。
    ///   - preset: 当前调弦配置；nil 表示半音阶调音。
    static func make(rawMidi: Double?,
                     referencePitch: Double,
                     preset: TuningPreset?) -> TuningReading? {
        guard let rawMidi, rawMidi.isFinite else { return nil }

        let referenceShift = 12.0 * log2(referencePitch / 440.0)
        let adjusted = rawMidi - referenceShift

        guard let preset, !preset.strings.isEmpty else {
            let nearest = adjusted.rounded()
            let cents = (adjusted - nearest) * 100.0
            return TuningReading(rawMidi: rawMidi,
                                 adjustedMidi: adjusted,
                                 frequency: NoteNames.frequency(midi: rawMidi, referenceA4: 440),
                                 noteName: NoteNames.name(midi: Int(nearest)),
                                 cents: cents,
                                 matchedStringIndex: nil,
                                 targetDisplayName: nil)
        }

        var best: (index: Int, diff: Double)?
        for (index, string) in preset.strings.enumerated() {
            let target = Double(string.midiNote) + string.centsOffset / 100.0
            let diff = adjusted - target
            guard abs(diff) <= 1.0 else { continue }
            if best == nil || abs(diff) < abs(best!.diff) {
                best = (index, diff)
            }
        }

        if let best {
            let string = preset.strings[best.index]
            return TuningReading(rawMidi: rawMidi,
                                 adjustedMidi: adjusted,
                                 frequency: NoteNames.frequency(midi: rawMidi, referenceA4: 440),
                                 noteName: string.displayName,
                                 cents: best.diff * 100.0,
                                 matchedStringIndex: best.index,
                                 targetDisplayName: string.displayName)
        }

        let nearest = adjusted.rounded()
        let cents = (adjusted - nearest) * 100.0
        return TuningReading(rawMidi: rawMidi,
                             adjustedMidi: adjusted,
                             frequency: NoteNames.frequency(midi: rawMidi, referenceA4: 440),
                             noteName: NoteNames.name(midi: Int(nearest)),
                             cents: cents,
                             matchedStringIndex: nil,
                             targetDisplayName: nil)
    }
}

// MARK: - 多音读数

nonisolated struct PolyStringReading: Identifiable, Equatable, Sendable {
    let id: Int
    /// 命中的弦在配置中的下标。
    let stringIndex: Int?
    /// 物理弦号（1 为最高音弦）。
    let stringNumber: Int?
    let midiPitch: Double
    let noteName: String
    let frequency: Double
    let cents: Double
    let status: TuningStatus
    let isMatched: Bool

    var isInTune: Bool { status.isInTune }
}

nonisolated enum PolyReadingBuilder {

    /// 把 Basic Pitch 的读数映射到目标调弦。
    /// 有乐器时优先按弦序排列；半音阶调音或未命中的音按音高从低到高排列。
    static func build(readouts: [TunerPolyReadout],
                      referencePitch: Double,
                      preset: TuningPreset?) -> [PolyStringReading] {
        guard !readouts.isEmpty else { return [] }

        let referenceShift = 12.0 * log2(referencePitch / 440.0)
        var candidates: [PolyStringReading] = []
        var usedStringIndices = Set<Int>()

        struct Raw {
            let id: Int
            let midi: Double
            let frequency: Double
            let distanceToNearest: Double
        }

        let raw: [Raw] = readouts.map { readout in
            let midi = Double(readout.midiPitch) + readout.cents / 100.0 - referenceShift
            return Raw(id: readout.id,
                       midi: midi,
                       frequency: readout.frequency,
                       distanceToNearest: abs(midi - midi.rounded()))
        }.sorted { $0.midi < $1.midi }

        // 先按弦号匹配，确保同一个音不会被两次分配给同一根弦。
        var unmatched: [Raw] = []

        for item in raw {
            guard let preset else {
                unmatched.append(item)
                continue
            }

            let pitchClass = ((Int(item.midi.rounded()) % 12) + 12) % 12
            var best: (index: Int, diff: Double)?
            for (index, string) in preset.strings.enumerated() {
                guard !usedStringIndices.contains(index) else { continue }
                guard string.pitchClass == pitchClass else { continue }
                let target = Double(string.midiNote) + string.centsOffset / 100.0
                let diff = item.midi - target
                guard abs(diff) <= 1.0 else { continue }
                if best == nil || abs(diff) < abs(best!.diff) {
                    best = (index, diff)
                }
            }

            if let best {
                usedStringIndices.insert(best.index)
                let string = preset.strings[best.index]
                candidates.append(PolyStringReading(
                    id: item.id,
                    stringIndex: best.index,
                    stringNumber: preset.stringNumber(at: best.index),
                    midiPitch: item.midi,
                    noteName: string.displayName,
                    frequency: item.frequency,
                    cents: best.diff * 100.0,
                    status: TuningStatus.from(cents: best.diff * 100.0),
                    isMatched: true
                ))
            } else {
                unmatched.append(item)
            }
        }

        for item in unmatched {
            let nearest = item.midi.rounded()
            let cents = (item.midi - nearest) * 100.0
            candidates.append(PolyStringReading(
                id: item.id,
                stringIndex: nil,
                stringNumber: nil,
                midiPitch: item.midi,
                noteName: NoteNames.name(midi: Int(nearest)),
                frequency: item.frequency,
                cents: cents,
                status: TuningStatus.from(cents: cents),
                isMatched: false
            ))
        }

        let matched = candidates.filter(\.isMatched).sorted { ($0.stringIndex ?? 0) < ($1.stringIndex ?? 0) }
        let others = candidates.filter { !$0.isMatched }.sorted { $0.midiPitch < $1.midiPitch }
        return matched + others
    }
}
