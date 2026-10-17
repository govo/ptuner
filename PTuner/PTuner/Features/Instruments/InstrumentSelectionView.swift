import SwiftUI

/// 乐器页：浏览、选择与管理全部调弦。
/// 点击行即选中并回到调音器；行内菜单负责新建、编辑与删除自定义调弦。
struct InstrumentSelectionView: View {
    @EnvironmentObject private var library: InstrumentLibrary
    @EnvironmentObject private var router: AppRouter

    @State private var searchText = ""
    @State private var category: InstrumentCategory = .all
    @State private var editorContext: EditorContext?
    @State private var pendingDelete: TuningPreset?

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 14) {
                    #if os(iOS)
                    pageHeader
                    #endif
                    InstrumentSearchField(text: $searchText)
                    InstrumentCategoryStrip(selection: $category)
                    content
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(L10n.tr("乐器"))
        #if os(iOS)
        // 隐藏系统大标题导航栏：它会在顶部留出一条大空白，并和自定义标题重复。
        .toolbar(.hidden, for: .navigationBar)
        #else
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
                .accessibilityLabel(L10n.tr("新建自定义调弦"))
            }
        }
        #endif
        .sheet(item: $editorContext) { context in
            CustomTuningEditorView(preset: context.preset, isNew: context.isNew)
                .environmentObject(library)
        }
        .confirmationDialog(
            L10n.tr("删除自定义调弦"),
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(L10n.tr("删除"), role: .destructive) {
                if let preset = pendingDelete {
                    library.deleteCustom(id: preset.id)
                }
                pendingDelete = nil
            }
            Button(L10n.tr("取消"), role: .cancel) {
                pendingDelete = nil
            }
        } message: {
            Text(L10n.tr("「%@」将被永久删除，无法恢复。", pendingDelete?.name ?? ""))
        }
    }

    // MARK: - 头部

    /// 与调音页保持一致的自定义标题行，替代系统大标题导航栏。
    private var pageHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "guitars")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .shadow(color: AppTheme.accent.opacity(0.6), radius: 7)

            Text(L10n.tr("乐器"))
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            Button {
                createCustomTuning()
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .frame(width: 36, height: 36)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.06))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.1), lineWidth: 0.8)
                            )
                    )
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(L10n.tr("新建自定义调弦"))
        }
    }

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        if isSearching {
            searchResults
        } else {
            switch category {
            case .all:
                allSections
            case .favorites:
                favoritesSection
            case .guitar, .bass, .ukulele, .other:
                selectedKindSection
            case .custom:
                customSection
            }
        }
    }

    @ViewBuilder
    private var searchResults: some View {
        let results = library.search(searchText)

        if results.isEmpty {
            EmptyStateView(icon: "magnifyingglass",
                           title: L10n.tr("没有找到匹配的调弦"),
                           message: L10n.tr("试试搜索乐器名称、调弦名称或音名。"))
        } else {
            section(title: L10n.tr("搜索结果"), presets: results)
        }
    }

    @ViewBuilder
    private var allSections: some View {
        kindSection(for: .guitar)
        kindSection(for: .bass)
        kindSection(for: .ukulele)
        kindSection(for: .other)
        customSection
    }

    @ViewBuilder
    private var favoritesSection: some View {
        if library.favoritePresets.isEmpty {
            EmptyStateView(icon: "star",
                           title: L10n.tr("还没有收藏的调弦"),
                           message: L10n.tr("点击调弦右侧的星标即可收藏，常用调弦会优先显示。"))
        } else {
            section(title: L10n.tr("收藏的乐器"), presets: library.favoritePresets)
        }
    }

    @ViewBuilder
    private var selectedKindSection: some View {
        if let kind = category.kind {
            kindSection(for: kind)
        }
    }

    @ViewBuilder
    private func kindSection(for kind: InstrumentKind) -> some View {
        let presets = library.presets(for: kind)
        if !presets.isEmpty {
            section(title: kind.displayName, presets: presets)
        } else if category != .all {
            EmptyStateView(icon: "guitars",
                           title: L10n.tr("暂无%@调弦", kind.displayName),
                           message: L10n.tr("可以新建一个自定义调弦。"))
        }
    }

    @ViewBuilder
    private var customSection: some View {
        let customs = library.customPresets.sorted { $0.createdAt > $1.createdAt }

        if customs.isEmpty {
            EmptyStateView(icon: "slider.horizontal.3",
                           title: L10n.tr("还没有自定义调弦"),
                           message: L10n.tr("创建一个全新的调弦配置，或从内置调弦复制后修改。"))
        } else {
            section(title: L10n.tr("自定义调弦"), presets: customs)
        }

        Button {
            createCustomTuning()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text(L10n.tr("新建自定义调弦"))
                    .font(.system(size: 14, weight: .semibold))
            }
            .foregroundStyle(AppTheme.accent)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.accentSoft)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 行

    private func section(title: String, presets: [TuningPreset]) -> some View {
        InstrumentGroupCard(title: title) {
            ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
                PresetManagedRow(
                    preset: preset,
                    isFavorite: library.isFavorite(preset),
                    isSelected: library.selectedPresetID == preset.id,
                    onSelect: {
                        select(preset)
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

    private func select(_ preset: TuningPreset) {
        library.select(preset)
        AppDiagnostics.breadcrumb(.tuner, "preset_selected")
        router.showTuner()
    }

    private func createCustomTuning() {
        let draft = library.makeDraft(kind: .guitar)
        editorContext = EditorContext(preset: draft, isNew: true)
    }
}

private struct EditorContext: Identifiable {
    let id = UUID()
    let preset: TuningPreset
    let isNew: Bool
}
