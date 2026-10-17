import SwiftUI

/// 乐器管理页：浏览全部内置调弦、管理自定义调弦与收藏。
struct InstrumentManagementView: View {
    @EnvironmentObject private var library: InstrumentLibrary
    @EnvironmentObject private var router: AppRouter

    @State private var searchText = ""
    @State private var filter: ManagementFilter = .all
    @State private var editorContext: EditorContext?
    @State private var pendingDelete: TuningPreset?

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    InstrumentSearchField(text: $searchText)
                    filterStrip
                    content
                    createButton
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("乐器管理")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    createCustomTuning()
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .frame(width: 30, height: 30)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("新建自定义调弦")
            }
        }
        .sheet(item: $editorContext) { context in
            CustomTuningEditorView(preset: context.preset, isNew: context.isNew)
                .environmentObject(library)
        }
        .confirmationDialog(
            "删除自定义调弦",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                if let preset = pendingDelete {
                    library.deleteCustom(id: preset.id)
                }
                pendingDelete = nil
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text("「\(pendingDelete?.name ?? "")」将被永久删除，无法恢复。")
        }
    }

    // MARK: - 筛选

    private var filterStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ManagementFilter.allCases) { item in
                    Button {
                        filter = item
                    } label: {
                        Text(item.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(filter == item ? AppTheme.onAccent : AppTheme.secondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(filter == item ? AppTheme.accent : AppTheme.controlBackground)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let results = library.search(searchText)
            if results.isEmpty {
                EmptyStateView(icon: "magnifyingglass",
                               title: "没有找到匹配的调弦",
                               message: "试试搜索乐器名称、调弦名称或音名。")
            } else {
                section(title: "搜索结果", presets: results)
            }
        } else {
            switch filter {
            case .all:
                allSections
            case .favorites:
                if library.favoritePresets.isEmpty {
                    EmptyStateView(icon: "star",
                                   title: "还没有收藏的调弦",
                                   message: "点击调弦右侧的星标即可收藏。")
                } else {
                    section(title: "收藏的乐器", presets: library.favoritePresets)
                }
            case .guitar:
                section(title: "吉他", presets: library.presets(for: .guitar))
            case .bass:
                section(title: "贝斯", presets: library.presets(for: .bass))
            case .ukulele:
                section(title: "尤克里里", presets: library.presets(for: .ukulele))
            case .other:
                otherSection
            case .custom:
                customSection
            }
        }
    }

    @ViewBuilder
    private var allSections: some View {
        if !library.favoritePresets.isEmpty {
            section(title: "收藏的乐器", presets: library.favoritePresets)
        }

        let guitarPresets = library.presets(for: .guitar)
        if !guitarPresets.isEmpty {
            section(title: "吉他", presets: guitarPresets)
        }

        let bassPresets = library.presets(for: .bass)
        if !bassPresets.isEmpty {
            section(title: "贝斯", presets: bassPresets)
        }

        let ukulelePresets = library.presets(for: .ukulele)
        if !ukulelePresets.isEmpty {
            section(title: "尤克里里", presets: ukulelePresets)
        }

        otherSection
        customSection
    }

    @ViewBuilder
    private var otherSection: some View {
        let presets = library.presets(for: .other)
        if !presets.isEmpty {
            section(title: "其他乐器", presets: presets)
        }
    }

    @ViewBuilder
    private var customSection: some View {
        let customs = library.customPresets.sorted { $0.createdAt > $1.createdAt }
        if customs.isEmpty {
            if filter == .all {
                EmptyStateView(icon: "slider.horizontal.3",
                               title: "还没有自定义调弦",
                               message: "点击下方按钮创建任意弦数与音高的调弦配置。")
            } else {
                EmptyStateView(icon: "slider.horizontal.3",
                               title: "还没有自定义调弦",
                               message: "创建一个全新的调弦配置，或从内置调弦复制后修改。")
            }
        } else {
            section(title: "自定义调弦", presets: customs)
        }
    }

    private func section(title: String, presets: [TuningPreset]) -> some View {
        InstrumentGroupCard(title: title) {
            ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                PresetManagedRow(
                    preset: preset,
                    isFavorite: library.isFavorite(preset),
                    isSelected: library.selectedPresetID == preset.id,
                    onSelect: {
                        library.select(preset)
                        router.showTuner()
                    },
                    onToggleFavorite: {
                        library.toggleFavorite(preset)
                    },
                    onEdit: preset.isBuiltIn ? nil : {
                        editorContext = EditorContext(preset: preset, isNew: false)
                    },
                    onDuplicate: {
                        let draft = library.makeDraft(from: preset)
                        editorContext = EditorContext(preset: draft, isNew: true)
                    },
                    onDelete: preset.isBuiltIn ? nil : {
                        pendingDelete = preset
                    }
                )

                if index < presets.count - 1 {
                    InstrumentRowDivider()
                }
            }
        }
    }

    private var createButton: some View {
        Button {
            createCustomTuning()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("新建自定义调弦")
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(AppTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.accentSoft)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func createCustomTuning() {
        let draft = library.makeDraft(kind: .guitar)
        editorContext = EditorContext(preset: draft, isNew: true)
    }
}

// MARK: - 筛选枚举

private enum ManagementFilter: String, CaseIterable, Identifiable {
    case all
    case favorites
    case guitar
    case bass
    case ukulele
    case other
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "全部"
        case .favorites: return "收藏"
        case .guitar: return "吉他"
        case .bass: return "贝斯"
        case .ukulele: return "尤克里里"
        case .other: return "其他"
        case .custom: return "自定义"
        }
    }
}

private struct EditorContext: Identifiable {
    let id = UUID()
    let preset: TuningPreset
    let isNew: Bool
}
