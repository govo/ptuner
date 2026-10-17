import Foundation

nonisolated struct ChordMatch: Equatable, Sendable {
    let name: String
    let rootPitchClass: Int
    let intervals: [Int]
    let pitchClasses: [Int]

    var compositionNames: [String] {
        pitchClasses.map { NoteNames.name(pitchClass: $0) }
    }
}

/// 基于当前同时发声的音高集合做和弦模板匹配。
/// 只输出有把握的结果；无法确定时返回 nil，由界面显示"识别中"。
nonisolated enum ChordRecognizer {

    private struct Template {
        let suffix: String
        let intervals: [Int]
        /// 需要优先满足的特征音（三音或挂留二度/四度）。
        let essential: Int
    }

    private static let templates: [Template] = [
        Template(suffix: "", intervals: [0, 4, 7], essential: 4),
        Template(suffix: "m", intervals: [0, 3, 7], essential: 3),
        Template(suffix: "7", intervals: [0, 4, 7, 10], essential: 4),
        Template(suffix: "m7", intervals: [0, 3, 7, 10], essential: 3),
        Template(suffix: "maj7", intervals: [0, 4, 7, 11], essential: 4),
        Template(suffix: "6", intervals: [0, 4, 7, 9], essential: 4),
        Template(suffix: "m6", intervals: [0, 3, 7, 9], essential: 3),
        Template(suffix: "dim", intervals: [0, 3, 6], essential: 3),
        Template(suffix: "aug", intervals: [0, 4, 8], essential: 4),
        Template(suffix: "sus2", intervals: [0, 2, 7], essential: 2),
        Template(suffix: "sus4", intervals: [0, 5, 7], essential: 5),
        Template(suffix: "m7b5", intervals: [0, 3, 6, 10], essential: 3),
        Template(suffix: "7sus4", intervals: [0, 5, 7, 10], essential: 5),
        Template(suffix: "add9", intervals: [0, 2, 4, 7], essential: 4),
        Template(suffix: "9", intervals: [0, 2, 4, 7, 10], essential: 4)
    ]

    /// - Parameter pitchClasses: 当前同时发声的音（去重后的 pitch class 集合）。
    static func recognize(pitchClasses: [Int]) -> ChordMatch? {
        let played = Set(pitchClasses.map { ((($0 % 12) + 12) % 12) })
        guard played.count >= 3 else { return nil }
        // 音数过多时（例如整体噪声）不做强行命名。
        guard played.count <= 6 else { return nil }

        var best: (score: Double, match: ChordMatch)?

        for root in 0..<12 {
            for template in templates {
                let tones = template.intervals.map { (root + $0) % 12 }
                let toneSet = Set(tones)
                guard played.contains(root) else { continue }
                guard played.contains((root + template.essential) % 12) else { continue }

                let missing = toneSet.subtracting(played)
                let extras = played.subtracting(toneSet)
                // 超过两个额外音基本可以判定不是这个和弦。
                if extras.count > 2 { continue }
                // 每个和弦至少命中三个音。
                if toneSet.intersection(played).count < 3 { continue }

                var score = Double(toneSet.intersection(played).count) * 3.0
                score -= Double(extras.count) * 2.2
                if missing.isEmpty { score += 2.0 }
                if played == toneSet { score += 1.0 }
                // 音数更多的和弦在完全命中时优先。
                if template.intervals.count >= 4 && missing.isEmpty { score += 0.6 }

                guard score >= 6.0 else { continue }

                let composition = tones
                let match = ChordMatch(name: NoteNames.name(pitchClass: root) + template.suffix,
                                       rootPitchClass: root,
                                       intervals: template.intervals,
                                       pitchClasses: composition)
                if best == nil || score > best!.score {
                    best = (score, match)
                }
            }
        }

        return best?.match
    }
}
