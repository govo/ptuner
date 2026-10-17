import Foundation

// MARK: - 图标轮廓

/// 图标轮廓：按乐器形态分成少数几种，避免为每件乐器单独绘制。
/// 具体乐器可在配置中用 `image` 覆盖这里选定的共享轮廓。
nonisolated enum InstrumentGlyphStyle: String, Codable, CaseIterable, Sendable {
    case guitar
    case lute
    case bowed
    case zither
    case harp
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

// MARK: - 限制

nonisolated enum TuningLimits {
    /// 自定义调弦允许的最大弦数。扬琴 402 型的十二平均律目标音可达 56 个，
    /// 古筝 21 弦、坎侬琴 26 组弦也需要从内置配置复制后继续编辑，
    /// 因此不能沿用旧的 12 弦上限。
    static let maxStringCount = 64
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
    /// 乐器 ID，对应 `Instruments.json` 中的 `instruments[].id`。
    /// 保留 `kind` 这个字段名与字符串类型，旧版本保存的自定义调弦可直接解码。
    var kind: String
    /// 按物理弦序排列：第一位是编号最大的弦（最低音弦），最后一位是 1 弦。
    var strings: [TuningString]
    var isBuiltIn: Bool
    var createdAt: Date

    init(id: String,
         name: String,
         kind: String,
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

    var instrument: InstrumentDefinition {
        InstrumentCatalog.instrument(id: kind) ?? InstrumentCatalog.fallbackInstrument
    }

    var kindDisplayName: String { instrument.displayName }

    var family: InstrumentFamily {
        instrument.family ?? InstrumentCatalog.fallbackFamily
    }

    /// 内置调弦的名称随界面语言切换；自定义调弦保留用户输入的名称。
    var displayName: String {
        isBuiltIn ? L10n.tr(name) : name
    }

    var title: String {
        "\(kindDisplayName) · \(displayName)"
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

/// 内置调弦完全由 `Instruments.json` 生成，新增乐器只需改配置。
nonisolated enum BuiltInTunings {
    static let all: [TuningPreset] = InstrumentCatalog.instruments.flatMap { instrument in
        instrument.sortedTunings.compactMap { definition in
            let strings = definition.strings.compactMap { TuningString(parsing: $0) }
            guard !strings.isEmpty else { return nil }
            return TuningPreset(id: definition.id,
                                name: definition.nameKey,
                                kind: instrument.id,
                                strings: strings,
                                isBuiltIn: true,
                                createdAt: Date(timeIntervalSince1970: 0))
        }
    }

    static func preset(id: String) -> TuningPreset? {
        all.first { $0.id == id }
    }

    static func presets(for instrumentID: String) -> [TuningPreset] {
        all.filter { $0.kind == instrumentID }
    }
}
