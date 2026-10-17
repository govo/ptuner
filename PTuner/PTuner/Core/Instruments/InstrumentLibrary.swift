import Combine
import Foundation

/// 乐器库：内置调弦、自定义调弦、收藏与当前选择。
/// 所有数据持久化在 UserDefaults，启动时恢复。
@MainActor
final class InstrumentLibrary: ObservableObject {

    static let freeTuningID = "__free__"

    /// 已移除的内置调弦 ID 指向合并后的等价调弦，避免旧收藏与当前选择失效。
    private static let legacyPresetAliases: [String: String] = [
        "resonator.standard": "guitar.standard",
        "resonator.openG": "guitar.openG",
        "resonator.openD": "guitar.openD",
        "dobro.standard": "guitar.standard",
        "dobro.openD": "guitar.openD"
    ]

    private static func resolvedPresetID(_ id: String) -> String {
        legacyPresetAliases[id] ?? id
    }

    @Published private(set) var customPresets: [TuningPreset] {
        didSet { persistCustomPresets() }
    }

    @Published private(set) var favoriteIDs: Set<String> {
        didSet { persistFavorites() }
    }

    @Published private(set) var selectedPresetID: String {
        didSet { defaults.set(selectedPresetID, forKey: Keys.selectedPresetID) }
    }

    /// 最近一次真正使用乐器时的调弦 ID，用于从半音阶模式一键切回。
    private var lastInstrumentPresetID: String

    private let defaults: UserDefaults

    private enum Keys {
        static let customPresets = "ptuner.customPresets"
        static let favoriteIDs = "ptuner.favoritePresetIDs"
        static let selectedPresetID = "ptuner.selectedPresetID"
        static let lastInstrumentPresetID = "ptuner.lastInstrumentPresetID"
        static let didSeedFavorites = "ptuner.didSeedFavorites"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        if let data = defaults.data(forKey: Keys.customPresets),
           let decoded = try? JSONDecoder().decode([TuningPreset].self, from: data) {
            customPresets = decoded
        } else {
            customPresets = []
        }

        if let stored = defaults.array(forKey: Keys.favoriteIDs) as? [String] {
            favoriteIDs = Set(stored.map(Self.resolvedPresetID))
        } else {
            favoriteIDs = []
        }

        let storedSelection = Self.resolvedPresetID(
            defaults.string(forKey: Keys.selectedPresetID) ?? "guitar.standard"
        )
        selectedPresetID = storedSelection
        let storedLastInstrument = defaults.string(forKey: Keys.lastInstrumentPresetID)
        lastInstrumentPresetID = Self.resolvedPresetID(
            storedLastInstrument
                ?? (storedSelection == Self.freeTuningID ? "guitar.standard" : storedSelection)
        )

        let hasPreset = BuiltInTunings.all.contains { $0.id == storedSelection }
            || customPresets.contains { $0.id == storedSelection }
            || storedSelection == Self.freeTuningID
        if !hasPreset {
            selectedPresetID = "guitar.standard"
        }
        if preset(id: lastInstrumentPresetID) == nil {
            lastInstrumentPresetID = "guitar.standard"
        }

        // 首次启动预置一个收藏，让收藏区有可用内容。
        if !defaults.bool(forKey: Keys.didSeedFavorites) {
            defaults.set(true, forKey: Keys.didSeedFavorites)
            if favoriteIDs.isEmpty {
                favoriteIDs = ["guitar.standard"]
            }
        }
    }

    // MARK: - 查询

    var allPresets: [TuningPreset] {
        BuiltInTunings.all + customPresets.sorted { $0.createdAt < $1.createdAt }
    }

    var selectedPreset: TuningPreset? {
        preset(id: selectedPresetID)
    }

    var isFreeTuning: Bool {
        selectedPresetID == Self.freeTuningID
    }

    func preset(id: String) -> TuningPreset? {
        customPresets.first { $0.id == id } ?? BuiltInTunings.preset(id: id)
    }

    func presets(for instrument: InstrumentDefinition) -> [TuningPreset] {
        allPresets.filter { $0.kind == instrument.id }
    }

    func customPresets(for instrument: InstrumentDefinition) -> [TuningPreset] {
        customPresets.filter { $0.kind == instrument.id }
    }

    func presets(for family: InstrumentFamily) -> [TuningPreset] {
        allPresets.filter { $0.instrument.familyID == family.id }
    }

    /// 某个族下按具体乐器分组的调弦，用于「全部」页展开。
    func instrumentGroups(in family: InstrumentFamily) -> [(instrument: InstrumentDefinition, presets: [TuningPreset])] {
        InstrumentCatalog.instruments(in: family.id).compactMap { instrument in
            let presets = presets(for: instrument)
            return presets.isEmpty ? nil : (instrument, presets)
        }
    }

    /// 配置中实际有调弦内容的族，避免筛选条出现空分类。
    var instrumentFamilies: [InstrumentFamily] {
        InstrumentCatalog.families.filter { family in
            allPresets.contains { $0.instrument.familyID == family.id }
        }
    }

    var favoritePresets: [TuningPreset] {
        allPresets.filter { favoriteIDs.contains($0.id) }
    }

    func isFavorite(_ preset: TuningPreset) -> Bool {
        favoriteIDs.contains(preset.id)
    }

    /// 搜索结果按乐器分组顺序排列。
    func search(_ query: String) -> [TuningPreset] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        return allPresets.filter { preset in
            preset.name.localizedCaseInsensitiveContains(trimmed)
                || preset.displayName.localizedCaseInsensitiveContains(trimmed)
                || preset.kindDisplayName.localizedCaseInsensitiveContains(trimmed)
                || preset.family.displayName.localizedCaseInsensitiveContains(trimmed)
                || preset.notesSummary.localizedCaseInsensitiveContains(trimmed)
                || preset.title.localizedCaseInsensitiveContains(trimmed)
        }
    }

    // MARK: - 选择

    func select(_ preset: TuningPreset) {
        rememberAsLastInstrument(preset.id)
        selectedPresetID = preset.id
    }

    func selectFreeTuning() {
        guard !isFreeTuning else { return }
        rememberAsLastInstrument(selectedPresetID)
        selectedPresetID = Self.freeTuningID
    }

    /// 从半音阶模式切回最近使用的乐器；没有可用记录时回到吉他标准调弦。
    func restoreLastInstrument() {
        if let preset = preset(id: lastInstrumentPresetID) {
            select(preset)
            return
        }
        rememberAsLastInstrument("guitar.standard")
        selectedPresetID = "guitar.standard"
    }

    private func rememberAsLastInstrument(_ id: String) {
        guard id != Self.freeTuningID else { return }
        lastInstrumentPresetID = id
        defaults.set(id, forKey: Keys.lastInstrumentPresetID)
    }

    // MARK: - 收藏

    func toggleFavorite(_ preset: TuningPreset) {
        if favoriteIDs.contains(preset.id) {
            favoriteIDs.remove(preset.id)
        } else {
            favoriteIDs.insert(preset.id)
        }
    }

    // MARK: - 自定义调弦

    @discardableResult
    func saveCustom(_ preset: TuningPreset) -> TuningPreset {
        var saved = preset
        saved.isBuiltIn = false
        // 内置调弦的 ID 是稳定字符串，自定义数据绝不能复用它们，
        // 否则查询时会遮蔽内置项，相当于把默认调弦改掉。
        if BuiltInTunings.preset(id: saved.id) != nil {
            saved.id = UUID().uuidString
        }
        if let index = customPresets.firstIndex(where: { $0.id == saved.id }) {
            customPresets[index] = saved
        } else {
            customPresets.append(saved)
        }
        select(saved)
        return saved
    }

    func deleteCustom(id: String) {
        customPresets.removeAll { $0.id == id }
        favoriteIDs.remove(id)
        if lastInstrumentPresetID == id {
            rememberAsLastInstrument("guitar.standard")
        }
        if selectedPresetID == id {
            selectedPresetID = "guitar.standard"
        }
    }

    /// 从任意配置复制出一份尚未保存的自定义草稿。
    func makeDraft(from preset: TuningPreset? = nil,
                   instrument: InstrumentDefinition? = nil) -> TuningPreset {
        if let preset {
            return preset.duplicated()
        }
        let instrument = instrument
            ?? InstrumentCatalog.instrument(id: "guitar")
            ?? InstrumentCatalog.fallbackInstrument
        let starterNotes = defaultStarterNotes(instrument: instrument)
        let strings = starterNotes.map { TuningString(parsing: $0) ?? TuningString(midiNote: 40) }
        return TuningPreset(id: UUID().uuidString,
                            name: L10n.tr("我的自定义调弦"),
                            kind: instrument.id,
                            strings: strings.isEmpty ? [TuningString(midiNote: 40)] : strings,
                            isBuiltIn: false)
    }

    private func defaultStarterNotes(instrument: InstrumentDefinition) -> [String] {
        // 优先沿用该乐器最常用的内置调弦，避免新建自定义调弦时出现陌生音高。
        if let preset = BuiltInTunings.all.first(where: { $0.kind == instrument.id }) {
            return preset.strings.map(\.displayName)
        }
        return ["C2", "G2", "D3", "A3", "E4", "B4"]
    }

    // MARK: - 持久化

    private func persistCustomPresets() {
        if let data = try? JSONEncoder().encode(customPresets) {
            defaults.set(data, forKey: Keys.customPresets)
        }
    }

    private func persistFavorites() {
        defaults.set(Array(favoriteIDs), forKey: Keys.favoriteIDs)
    }
}
