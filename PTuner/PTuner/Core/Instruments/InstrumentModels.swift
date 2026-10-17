import Foundation

// MARK: - 乐器类型

nonisolated enum InstrumentKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case guitar
    case bass
    case ukulele
    case other

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .guitar: return L10n.tr("吉他")
        case .bass: return L10n.tr("贝斯")
        case .ukulele: return L10n.tr("尤克里里")
        case .other: return L10n.tr("其他乐器")
        }
    }

    var shortDisplayName: String {
        switch self {
        case .other: return L10n.tr("其他")
        default: return displayName
        }
    }

    /// 切换乐器类型时用于新建弦数的参考值。
    var defaultStringCount: Int {
        switch self {
        case .guitar: return 6
        case .bass: return 4
        case .ukulele: return 4
        case .other: return 6
        }
    }
}

// MARK: - 音名拼写

nonisolated enum Accidental: String, Codable, CaseIterable, Sendable {
    case natural
    case sharp
    case flat
}

nonisolated struct NoteSpelling: Identifiable, Hashable, Sendable {
    let pitchClass: Int
    let accidental: Accidental
    let name: String

    var id: String { "\(name)-\(pitchClass)" }

    static let all: [NoteSpelling] = [
        NoteSpelling(pitchClass: 0, accidental: .natural, name: "C"),
        NoteSpelling(pitchClass: 1, accidental: .sharp, name: "C#"),
        NoteSpelling(pitchClass: 1, accidental: .flat, name: "Db"),
        NoteSpelling(pitchClass: 2, accidental: .natural, name: "D"),
        NoteSpelling(pitchClass: 3, accidental: .sharp, name: "D#"),
        NoteSpelling(pitchClass: 3, accidental: .flat, name: "Eb"),
        NoteSpelling(pitchClass: 4, accidental: .natural, name: "E"),
        NoteSpelling(pitchClass: 5, accidental: .natural, name: "F"),
        NoteSpelling(pitchClass: 6, accidental: .sharp, name: "F#"),
        NoteSpelling(pitchClass: 6, accidental: .flat, name: "Gb"),
        NoteSpelling(pitchClass: 7, accidental: .natural, name: "G"),
        NoteSpelling(pitchClass: 8, accidental: .sharp, name: "G#"),
        NoteSpelling(pitchClass: 8, accidental: .flat, name: "Ab"),
        NoteSpelling(pitchClass: 9, accidental: .natural, name: "A"),
        NoteSpelling(pitchClass: 10, accidental: .sharp, name: "A#"),
        NoteSpelling(pitchClass: 10, accidental: .flat, name: "Bb"),
        NoteSpelling(pitchClass: 11, accidental: .natural, name: "B")
    ]

    static func spellings(pitchClass: Int) -> [NoteSpelling] {
        all.filter { $0.pitchClass == pitchClass }
    }

    static func preferred(for pitchClass: Int, accidental: Accidental) -> NoteSpelling {
        if let match = all.first(where: { $0.pitchClass == pitchClass && $0.accidental == accidental }) {
            return match
        }
        if let natural = all.first(where: { $0.pitchClass == pitchClass && $0.accidental == .natural }) {
            return natural
        }
        return all.first(where: { $0.pitchClass == pitchClass }) ?? all[0]
    }
}

nonisolated enum NoteNames {
    private static let sharpNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private static let flatNames = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]

    static func name(pitchClass: Int, accidental: Accidental = .sharp) -> String {
        let index = ((pitchClass % 12) + 12) % 12
        switch accidental {
        case .flat:
            return flatNames[index]
        case .natural, .sharp:
            return sharpNames[index]
        }
    }

    static func name(midi: Int) -> String {
        "\(name(pitchClass: midi % 12))\(octave(midi: midi))"
    }

    static func octave(midi: Int) -> Int {
        Int(floor(Double(midi) / 12.0)) - 1
    }

    static func frequency(midi: Double, referenceA4: Double) -> Double {
        referenceA4 * pow(2.0, (midi - 69.0) / 12.0)
    }
}

// MARK: - 单根弦

nonisolated struct TuningString: Codable, Hashable, Identifiable, Sendable {
    var id: UUID
    /// 0 = C, 1 = C#/Db, ... 11 = B。
    var pitchClass: Int
    var octave: Int
    var accidental: Accidental
    /// 该弦相对标准音高的音分偏移，可正可负。
    var centsOffset: Double

    init(id: UUID = UUID(),
         pitchClass: Int,
         octave: Int,
         accidental: Accidental = .sharp,
         centsOffset: Double = 0) {
        self.id = id
        self.pitchClass = ((pitchClass % 12) + 12) % 12
        self.octave = octave
        self.accidental = accidental
        self.centsOffset = centsOffset
    }

    init(id: UUID = UUID(), midiNote: Int, accidental: Accidental = .sharp, centsOffset: Double = 0) {
        self.init(id: id,
                  pitchClass: midiNote % 12,
                  octave: Int(floor(Double(midiNote) / 12.0)) - 1,
                  accidental: accidental,
                  centsOffset: centsOffset)
    }

    /// 解析 "E2"、"Eb3"、"F#1" 这类写法。
    init?(parsing text: String) {
        let characters = Array(text.trimmingCharacters(in: .whitespaces))
        guard !characters.isEmpty else { return nil }

        let letter = String(characters[0]).uppercased()
        let naturalMap: [String: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]
        guard var pitchClass = naturalMap[letter] else { return nil }

        var accidental = Accidental.natural
        var cursor = 1
        if characters.count > 1 {
            if characters[1] == "#" {
                accidental = .sharp
                pitchClass = (pitchClass + 1) % 12
                cursor = 2
            } else if characters[1] == "b" {
                accidental = .flat
                pitchClass = (pitchClass + 11) % 12
                cursor = 2
            }
        }

        let octaveText = String(characters[cursor...])
        guard let octave = Int(octaveText), (0...9).contains(octave) else { return nil }

        self.init(pitchClass: pitchClass, octave: octave, accidental: accidental)
    }

    var midiNote: Int {
        (octave + 1) * 12 + pitchClass
    }

    var noteName: String {
        NoteNames.name(pitchClass: pitchClass, accidental: accidental)
    }

    var displayName: String {
        "\(noteName)\(octave)"
    }

    var spelling: NoteSpelling {
        NoteSpelling.preferred(for: pitchClass, accidental: accidental)
    }

    func frequency(referenceA4: Double) -> Double {
        NoteNames.frequency(midi: Double(midiNote) + centsOffset / 100.0,
                            referenceA4: referenceA4)
    }
}

// MARK: - 调弦配置

nonisolated struct TuningPreset: Codable, Hashable, Identifiable, Sendable {
    /// 内置配置使用稳定字符串 ID，自定义配置使用 UUID 字符串。
    var id: String
    var name: String
    var kind: InstrumentKind
    /// 按物理弦序排列：第一位是编号最大的弦（最低音弦），最后一位是 1 弦。
    var strings: [TuningString]
    var isBuiltIn: Bool
    var createdAt: Date

    init(id: String,
         name: String,
         kind: InstrumentKind,
         strings: [TuningString],
         isBuiltIn: Bool,
         createdAt: Date = Date()) {
        self.id = id
        self.name = name
        self.kind = kind
        self.strings = strings
        self.isBuiltIn = isBuiltIn
        self.createdAt = createdAt
    }

    /// 内置调弦的名称随界面语言切换；自定义调弦保留用户输入的名称。
    var displayName: String {
        isBuiltIn ? L10n.tr(name) : name
    }

    var title: String {
        "\(kind.displayName) · \(displayName)"
    }

    /// 例如 "E A D G B E"，用于列表副标题。
    var notesSummary: String {
        strings.map(\.noteName).joined(separator: " ")
    }

    var stringCount: Int { strings.count }

    func stringNumber(at index: Int) -> Int {
        strings.count - index
    }

    func stringIndex(forNumber number: Int) -> Int? {
        let index = strings.count - number
        return strings.indices.contains(index) ? index : nil
    }

    /// 复制一份新的自定义配置。
    func duplicated(nameSuffix: String? = nil) -> TuningPreset {
        var copy = self
        copy.id = UUID().uuidString
        copy.name = displayName + " " + (nameSuffix ?? L10n.tr("副本"))
        copy.isBuiltIn = false
        copy.createdAt = Date()
        copy.strings = strings.map { TuningString(pitchClass: $0.pitchClass,
                                                  octave: $0.octave,
                                                  accidental: $0.accidental,
                                                  centsOffset: $0.centsOffset) }
        return copy
    }
}

// MARK: - 内置调弦

nonisolated enum BuiltInTunings {
    static let all: [TuningPreset] = guitar + bass + ukulele

    static func preset(id: String) -> TuningPreset? {
        all.first { $0.id == id }
    }

    static let guitar: [TuningPreset] = [
        make("guitar.standard", "标准调弦", .guitar, ["E2", "A2", "D3", "G3", "B3", "E4"]),
        make("guitar.dropD", "Drop D", .guitar, ["D2", "A2", "D3", "G3", "B3", "E4"]),
        make("guitar.openG", "Open G", .guitar, ["D2", "G2", "D3", "G3", "B3", "D4"]),
        make("guitar.halfStep", "全降半音", .guitar, ["Eb2", "Ab2", "Db3", "Gb3", "Bb3", "Eb4"]),
        make("guitar.dropDHalfStep", "Drop D 全降半音", .guitar, ["Db2", "Ab2", "Db3", "Gb3", "Bb3", "Eb4"]),
        make("guitar.sevenString", "7 弦标准", .guitar, ["B1", "E2", "A2", "D3", "G3", "B3", "E4"])
    ]

    static let bass: [TuningPreset] = [
        make("bass.standard4", "四弦标准调弦", .bass, ["E1", "A1", "D2", "G2"]),
        make("bass.standard5", "五弦标准调弦", .bass, ["B0", "E1", "A1", "D2", "G2"]),
        make("bass.halfStep", "全降半音", .bass, ["Eb1", "Ab1", "Db2", "Gb2"])
    ]

    static let ukulele: [TuningPreset] = [
        make("ukulele.standard", "标准调弦", .ukulele, ["G4", "C4", "E4", "A4"]),
        make("ukulele.lowG", "Low G", .ukulele, ["G3", "C4", "E4", "A4"])
    ]

    private static func make(_ id: String,
                             _ name: String,
                             _ kind: InstrumentKind,
                             _ notes: [String]) -> TuningPreset {
        let strings = notes.compactMap { TuningString(parsing: $0) }
        return TuningPreset(id: id,
                            name: name,
                            kind: kind,
                            strings: strings,
                            isBuiltIn: true,
                            createdAt: Date(timeIntervalSince1970: 0))
    }
}
