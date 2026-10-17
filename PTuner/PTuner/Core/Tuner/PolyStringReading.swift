import Combine
import Foundation

// MARK: - 单根弦的整琴校验读数

nonisolated struct PolyStringMatch: Equatable, Sendable {
    let readoutID: Int
    /// 已按 referencePitch 归一化的连续 MIDI 音高。
    let adjustedMidi: Double
    /// 按参考音高换算后的检测音名，例如 "E2"。
    let detectedNoteName: String
    /// Basic Pitch 输出的实际频率（A4 = 440）。
    let frequency: Double
    /// 相对目标弦（含 preset 的音分偏移）的音分偏差。
    let cents: Double

    var status: TuningStatus { TuningStatus.from(cents: cents) }
}

/// 以选定乐器的调弦配置为主体的一根目标弦。
/// 未拨响时 `match == nil`，界面显示「待检测」。
nonisolated struct PolyStringSlot: Identifiable, Equatable, Sendable {
    /// 与 stringIndex 相同，保证列表 identity 稳定。
    let id: Int
    let stringIndex: Int
    /// 物理弦号，1 为最高音弦。
    let stringNumber: Int
    let targetNoteName: String
    let targetMidi: Double
    let targetFrequency: Double
    var match: PolyStringMatch?

    var isDetected: Bool { match != nil }
    var cents: Double? { match?.cents }
    var status: TuningStatus { match?.status ?? .idle }
    var detectedNoteName: String? { match?.detectedNoteName }
    var frequency: Double? { match?.frequency }
}

// MARK: - 构建器

nonisolated enum PolyStringReadingBuilder {
    /// 匹配容差（半音）。1.5 = ±150 cents。
    /// 明显跑音的弦通常会越过一个半音，门限太窄会让它直接消失成「待检测」，
    /// 用户就看不到音分正在往哪个方向变化。
    static let assignmentToleranceSemitones = 1.5

    /// 把当前检测到的音分配给调弦配置里的每一根弦。
    /// 返回的数组与 `preset.strings` 顺序一致，未命中的弦也会保留。
    static func buildSlots(readouts: [TunerPolyReadout],
                           referencePitch: Double,
                           preset: TuningPreset?) -> [PolyStringSlot] {
        guard let preset, !preset.strings.isEmpty else { return [] }

        let referenceShift = 12.0 * log2(referencePitch / 440.0)
        let adjusted = readouts.map { readout in
            (readout: readout,
             adjustedMidi: Double(readout.midiPitch) + readout.cents / 100.0 - referenceShift)
        }

        // 先收集所有可行的 (弦, 读数) 组合，再按偏差从小到大全局分配，
        // 避免读数顺序造成相邻弦抢占。
        var candidates: [(slotIndex: Int, readoutIndex: Int, distance: Double)] = []
        for (slotIndex, string) in preset.strings.enumerated() {
            let target = Double(string.midiNote) + string.centsOffset / 100.0
            for (readoutIndex, item) in adjusted.enumerated() {
                let distance = abs(item.adjustedMidi - target)
                guard distance <= assignmentToleranceSemitones else { continue }
                candidates.append((slotIndex, readoutIndex, distance))
            }
        }

        candidates.sort {
            if $0.distance != $1.distance { return $0.distance < $1.distance }
            if $0.slotIndex != $1.slotIndex { return $0.slotIndex < $1.slotIndex }
            return adjusted[$0.readoutIndex].readout.id < adjusted[$1.readoutIndex].readout.id
        }

        var matches: [Int: PolyStringMatch] = [:]
        var usedReadoutIndices = Set<Int>()
        for candidate in candidates {
            guard matches[candidate.slotIndex] == nil,
                  !usedReadoutIndices.contains(candidate.readoutIndex) else { continue }

            let item = adjusted[candidate.readoutIndex]
            let string = preset.strings[candidate.slotIndex]
            let target = Double(string.midiNote) + string.centsOffset / 100.0
            let cents = (item.adjustedMidi - target) * 100.0
            let nearestMidi = Int(item.adjustedMidi.rounded())

            matches[candidate.slotIndex] = PolyStringMatch(
                readoutID: item.readout.id,
                adjustedMidi: item.adjustedMidi,
                detectedNoteName: NoteNames.name(midi: nearestMidi),
                frequency: item.readout.frequency,
                cents: cents
            )
            usedReadoutIndices.insert(candidate.readoutIndex)
        }

        return preset.strings.enumerated().map { index, string in
            PolyStringSlot(
                id: index,
                stringIndex: index,
                stringNumber: preset.stringNumber(at: index),
                targetNoteName: string.displayName,
                targetMidi: Double(string.midiNote) + string.centsOffset / 100.0,
                targetFrequency: string.frequency(referenceA4: referencePitch),
                match: matches[index]
            )
        }
    }
}

// MARK: - 检测结果保持

/// Basic Pitch 只为「当前仍在发声」的音提供读数。整琴扫弦时所有音会同时消失，
/// 逐弦校验来不及看清。这里保留最近几秒的最后一笔结果，让卡片短暂停留在读数状态。
@MainActor
final class PolyStringVerificationStore: ObservableObject {
    struct Entry {
        let match: PolyStringMatch
        let timestamp: Date
    }

    struct ResolvedSlot: Identifiable {
        let slot: PolyStringSlot
        /// true 表示读数来自保持缓存，而不是此刻仍在发声。
        let isRetained: Bool

        var id: Int { slot.id }
    }

    @Published private(set) var retained: [Int: Entry] = [:]
    /// 只短暂保留上一笔读数，避免弦已经衰减后表盘长时间停在旧值。
    var retentionInterval: TimeInterval = 1.0

    func ingest(_ slots: [PolyStringSlot], at date: Date = Date()) {
        guard !slots.isEmpty else { return }

        var next = retained
        for slot in slots {
            if let match = slot.match {
                next[slot.stringIndex] = Entry(match: match, timestamp: date)
            }
        }
        next = next.filter { date.timeIntervalSince($0.value.timestamp) <= retentionInterval }
        retained = next
    }

    func purgeExpired(at date: Date = Date()) {
        let expired = retained.keys.filter { key in
            guard let entry = retained[key] else { return false }
            return date.timeIntervalSince(entry.timestamp) > retentionInterval
        }
        guard !expired.isEmpty else { return }
        for key in expired {
            retained.removeValue(forKey: key)
        }
    }

    /// fresh 读数优先；没有 fresh 时用缓存补齐，并标记为保持状态。
    func resolve(_ fresh: [PolyStringSlot], at date: Date = Date()) -> [ResolvedSlot] {
        fresh.map { slot in
            if slot.isDetected {
                return ResolvedSlot(slot: slot, isRetained: false)
            }
            guard let entry = retained[slot.stringIndex],
                  date.timeIntervalSince(entry.timestamp) <= retentionInterval else {
                return ResolvedSlot(slot: slot, isRetained: false)
            }
            var filled = slot
            filled.match = entry.match
            return ResolvedSlot(slot: filled, isRetained: true)
        }
    }

    func reset() {
        retained = [:]
    }
}
