import Combine
import Foundation

/// 乐器库：内置调弦、自定义调弦、收藏与当前选择。
/// 所有数据持久化在 UserDefaults，启动时恢复。
@MainActor
final class InstrumentLibrary: ObservableObject {

    static let freeTuningID = "__free__"

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
            favoriteIDs = Set(stored)
        } else {
            favoriteIDs = []
        }

        let storedSelection = defaults.string(forKey: Keys.selectedPresetID) ?? "guitar.standard"
        selectedPresetID = storedSelection
        lastInstrumentPresetID = defaults.string(forKey: Keys.lastInstrumentPresetID)
            ?? (storedSelection == Self.freeTuningID ? "guitar.standard" : storedSelection)

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

    func presets(for kind: InstrumentKind) -> [TuningPreset] {
        allPresets.filter { $0.kind == kind }
    }

    func customPresets(for kind: InstrumentKind) -> [TuningPreset] {
        customPresets.filter { $0.kind == kind }
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
                || preset.kind.displayName.localizedCaseInsensitiveContains(trimmed)
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
    func makeDraft(from preset: TuningPreset? = nil, kind: InstrumentKind = .guitar) -> TuningPreset {
        if let preset {
            return preset.duplicated()
        }
        let defaults = kind.defaultStringCount
        let strings = (0..<defaults).map { index -> TuningString in
            // 从低弦到高弦按四度递增，生成一个可编辑的起点。
            let base = TuningString(parsing: defaultStarterNotes(kind: kind).dropFirst(index).first ?? "E2")
                ?? TuningString(midiNote: 40)
            return base
        }
        return TuningPreset(id: UUID().uuidString,
                            name: L10n.tr("我的自定义调弦"),
                            kind: kind,
                            strings: strings.isEmpty ? [TuningString(midiNote: 40)] : strings,
                            isBuiltIn: false)
    }

    private func defaultStarterNotes(kind: InstrumentKind) -> [String] {
        switch kind {
        case .guitar: return ["E2", "A2", "D3", "G3", "B3", "E4"]
        case .bass: return ["E1", "A1", "D2", "G2", "B2", "E3"]
        case .ukulele: return ["G4", "C4", "E4", "A4", "D5", "G5"]
        case .other: return ["C2", "G2", "D3", "A3", "E4", "B4"]
        }
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
