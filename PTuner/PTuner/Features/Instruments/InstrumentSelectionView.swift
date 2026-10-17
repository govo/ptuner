import SwiftUI

/// 乐器选择页：按分类、收藏或搜索快速切换当前调弦。
struct InstrumentSelectionView: View {
    @EnvironmentObject private var library: InstrumentLibrary
    @EnvironmentObject private var router: AppRouter

    @State private var searchText = ""
    @State private var category: InstrumentCategory = .guitar

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    tuningModeSection

                    VStack(alignment: .leading, spacing: 8) {
                        Text("选择乐器")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryText)
                            .padding(.leading, 4)

                        InstrumentSearchField(text: $searchText)
                        InstrumentCategoryStrip(selection: $category)
                    }

                    if isSearching {
                        searchResults
                    } else {
                        switch category {
                        case .favorites:
                            favoritesSection
                        case .custom:
                            customSection
                        default:
                            if !library.favoritePresets.isEmpty {
                                favoritesSection
                            }
                            categorySection
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: 760)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle("选择调音方式")
    }

    // MARK: - 搜索

    @ViewBuilder
    private var searchResults: some View {
        let results = library.search(searchText)

        if results.isEmpty {
            EmptyStateView(icon: "magnifyingglass",
                           title: "没有找到匹配的调弦",
                           message: "试试搜索乐器名称、调弦名称或音名。")
        } else {
            InstrumentGroupCard(title: "搜索结果") {
                rows(results)
            }
        }
    }

    // MARK: - 收藏

    @ViewBuilder
    private var favoritesSection: some View {
        if library.favoritePresets.isEmpty {
            EmptyStateView(icon: "star",
                           title: "还没有收藏的调弦",
                           message: "点击调弦右侧的星标即可收藏，常用调弦会优先显示。")
        } else {
            InstrumentGroupCard(title: "收藏的乐器") {
                rows(library.favoritePresets)
            }
        }
    }

    // MARK: - 分类

    @ViewBuilder
    private var categorySection: some View {
        if let kind = category.kind, kind != .other {
            let presets = library.presets(for: kind)
            InstrumentGroupCard(title: "\(kind.displayName)调弦") {
                if presets.isEmpty {
                    EmptyStateView(icon: "guitars",
                                   title: "暂无\(kind.displayName)调弦",
                                   message: "可以在乐器管理中创建自定义调弦。")
                } else {
                    rows(presets)
                }
            }
        } else {
            let presets = library.presets(for: .other)
            if presets.isEmpty {
                EmptyStateView(icon: "tuningfork",
                               title: "暂无其他乐器",
                               message: "在乐器管理中创建自定义调弦时选择「其他乐器」即可。")
            } else {
                InstrumentGroupCard(title: "其他乐器") {
                    rows(presets)
                }
            }
        }
    }

    // MARK: - 自定义

    @ViewBuilder
    private var customSection: some View {
        let customs = library.customPresets.sorted { $0.createdAt > $1.createdAt }

        if customs.isEmpty {
            EmptyStateView(icon: "slider.horizontal.3",
                           title: "还没有自定义调弦",
                           message: "在乐器管理中创建任意弦数和音高的调弦配置。")
        } else {
            InstrumentGroupCard(title: "自定义调弦") {
                rows(customs)
            }
        }

        Button {
            router.showManagement()
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "plus")
                    .font(.system(size: 13, weight: .bold))
                Text("前往乐器管理")
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

    // MARK: - 调音方式

    private var tuningModeSection: some View {
        InstrumentGroupCard(title: "调音方式") {
            TuningModeRow(icon: "guitars",
                          title: "按乐器调音",
                          subtitle: "按所选乐器的目标弦逐一调音",
                          isSelected: !library.isFreeTuning) {
                library.restoreLastInstrument()
                AppDiagnostics.breadcrumb(.tuner, "instrument_mode_selected")
                router.showTuner()
            }

            InstrumentRowDivider()

            TuningModeRow(icon: "waveform",
                          title: "半音阶调音",
                          subtitle: "不用乐器，自动识别任意音高",
                          isSelected: library.isFreeTuning) {
                library.selectFreeTuning()
                AppDiagnostics.breadcrumb(.tuner, "chromatic_selected")
                router.showTuner()
            }
        }
    }

    // MARK: - 行

    private func rows(_ presets: [TuningPreset]) -> some View {
        ForEach(Array(presets.enumerated()), id: \.element.id) { index, preset in
            PresetSelectableRow(
                preset: preset,
                isFavorite: library.isFavorite(preset),
                isSelected: library.selectedPresetID == preset.id,
                onSelect: {
                    library.select(preset)
                    AppDiagnostics.breadcrumb(.tuner, "preset_selected")
                    router.showTuner()
                },
                onToggleFavorite: {
                    library.toggleFavorite(preset)
                }
            )

            if index < presets.count - 1 {
                InstrumentRowDivider()
            }
        }
    }
}
