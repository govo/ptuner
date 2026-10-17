import Foundation

// MARK: - 配置模型

/// 乐器族配置。对应 `Resources/Instruments.json` 中的 `families`。
nonisolated struct InstrumentFamily: Codable, Identifiable, Hashable, Sendable {
    let id: String
    /// 本地化 key，同时作为简体中文原文。
    let nameKey: String
    let shortNameKey: String
    /// 十六进制识别色，例如 "#4C8DFF"。
    let tint: String
    let order: Int

    var displayName: String { L10n.tr(nameKey) }
    var shortDisplayName: String { L10n.tr(shortNameKey) }
}

/// 单条内置调弦配置。对应乐器下的 `tunings`。
nonisolated struct TuningDefinition: Codable, Hashable, Sendable {
    let id: String
    let nameKey: String
    /// 从最低音弦到最高音弦的绝对音名，例如 ["E2", "A2", "D3", "G3", "B3", "E4"]。
    let strings: [String]
    /// 同一乐器内的展示顺序。
    let order: Int
}

/// 单件乐器配置。对应 `instruments`。
nonisolated struct InstrumentDefinition: Codable, Identifiable, Hashable, Sendable {
    let id: String
    let familyID: String
    let nameKey: String
    /// 共享矢量轮廓。形态相近的乐器可以复用同一个值。
    let glyph: InstrumentGlyphStyle
    /// Assets 中的图片名。存在时优先于 `glyph`，用于给单件乐器配置专属图片。
    let imageName: String?
    /// 可选的乐器专属识别色；缺省时跟随所属族。
    let tint: String?
    let defaultStringCount: Int
    /// 是否在筛选条上单独占一个入口（吉他、贝斯、尤克里里）。
    let featured: Bool
    let order: Int
    let tunings: [TuningDefinition]

    enum CodingKeys: String, CodingKey {
        case id
        case familyID
        case nameKey
        case glyph
        case imageName = "image"
        case tint
        case defaultStringCount
        case featured
        case order
        case tunings
    }

    var displayName: String { L10n.tr(nameKey) }

    var family: InstrumentFamily? {
        InstrumentCatalog.family(id: familyID)
    }

    var sortedTunings: [TuningDefinition] {
        tunings.sorted { $0.order < $1.order }
    }
}

private nonisolated struct InstrumentCatalogFile: Codable, Sendable {
    let families: [InstrumentFamily]
    let instruments: [InstrumentDefinition]
}

// MARK: - 配置读取

/// 乐器目录：启动时读取 `Instruments.json`，之后所有分类、图标与内置调弦都从这里取。
nonisolated enum InstrumentCatalog {

    /// 配置缺失或乐器 ID 未知时的兜底定义，保证旧版本保存的自定义调弦仍可用。
    static let fallbackInstrument = InstrumentDefinition(
        id: "other",
        familyID: "other",
        nameKey: "其他乐器",
        glyph: .guitar,
        imageName: nil,
        tint: nil,
        defaultStringCount: 6,
        featured: false,
        order: Int.max,
        tunings: []
    )

    static let fallbackFamily = InstrumentFamily(
        id: "other",
        nameKey: "其他乐器",
        shortNameKey: "其他",
        tint: "#2DD4BF",
        order: Int.max
    )

    private static let file: InstrumentCatalogFile = loadFile()

    static var families: [InstrumentFamily] {
        file.families.sorted { $0.order < $1.order }
    }

    static var instruments: [InstrumentDefinition] {
        file.instruments.sorted { $0.order < $1.order }
    }

    static var featuredInstruments: [InstrumentDefinition] {
        instruments.filter(\.featured)
    }

    /// 已合并的旧乐器 ID。旧版本保存的自定义调弦可能仍带有这些 ID，
    /// 解析时指向合并后的乐器，避免显示成“其他乐器”或丢失分类。
    private static let legacyAliases: [String: String] = [
        "resonatorGuitar": "guitar"
    ]

    static func instrument(id: String) -> InstrumentDefinition? {
        let resolvedID = legacyAliases[id] ?? id
        return file.instruments.first { $0.id == resolvedID }
    }

    static func family(id: String) -> InstrumentFamily? {
        file.families.first { $0.id == id }
    }

    static func instruments(in familyID: String) -> [InstrumentDefinition] {
        instruments.filter { $0.familyID == familyID }
    }

    private static func loadFile() -> InstrumentCatalogFile {
        guard
            let url = Bundle.main.url(forResource: "Instruments", withExtension: "json"),
            let data = try? Data(contentsOf: url),
            let decoded = try? JSONDecoder().decode(InstrumentCatalogFile.self, from: data)
        else {
            assertionFailure("Instruments.json 缺失或格式错误")
            return InstrumentCatalogFile(families: [], instruments: [])
        }
        return decoded
    }
}
