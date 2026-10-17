import SwiftUI

// MARK: - 分类

enum InstrumentCategory: String, CaseIterable, Identifiable {
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
        case .all: return L10n.tr("全部")
        case .favorites: return L10n.tr("收藏")
        case .guitar: return L10n.tr("吉他")
        case .bass: return L10n.tr("贝斯")
        case .ukulele: return L10n.tr("尤克里里")
        case .other: return L10n.tr("其他")
        case .custom: return L10n.tr("自定义")
        }
    }

    var kind: InstrumentKind? {
        switch self {
        case .guitar: return .guitar
        case .bass: return .bass
        case .ukulele: return .ukulele
        case .other: return .other
        case .all, .favorites, .custom: return nil
        }
    }
}

struct InstrumentCategoryStrip: View {
    @Binding var selection: InstrumentCategory

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(InstrumentCategory.allCases) { category in
                    Button {
                        selection = category
                    } label: {
                        Text(category.title)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(selection == category ? AppTheme.onAccent : AppTheme.secondaryText)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(
                                Capsule()
                                    .fill(selection == category ? AppTheme.accent : AppTheme.controlBackground)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 1)
        }
    }
}

// MARK: - 搜索框

struct InstrumentSearchField: View {
    @Binding var text: String
    var placeholder: String = L10n.tr("搜索乐器或调弦方式")

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.tertiaryText)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.primaryText)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 13)
        .padding(.vertical, 10)
        .background(GlassControlBackground(cornerRadius: 12))
    }
}

// MARK: - 行

struct PresetManagedRow: View {
    let preset: TuningPreset
    let isFavorite: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleFavorite: () -> Void
    /// 只有自定义调弦才允许编辑；内置调弦传 nil。
    let onEdit: (() -> Void)?
    let onDuplicate: () -> Void
    let onDelete: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    presetIcon

                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text(preset.title)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(AppTheme.primaryText)
                                .lineLimit(1)

                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(AppTheme.accent)
                            }
                        }

                        Text(preset.notesSummary)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                    }

                    Spacer(minLength: 4)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button(action: onToggleFavorite) {
                Image(systemName: isFavorite ? "star.fill" : "star")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(isFavorite ? AppTheme.warning : AppTheme.tertiaryText)
                    .frame(width: 32, height: 32)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Menu {
                Button(L10n.tr("设为当前调弦"), action: onSelect)

                Button(isFavorite ? L10n.tr("取消收藏") : L10n.tr("收藏"), action: onToggleFavorite)

                Button(L10n.tr("以此新建自定义调弦"), action: onDuplicate)

                if let onEdit, !preset.isBuiltIn {
                    Divider()
                    Button(L10n.tr("编辑调弦"), action: onEdit)
                    if let onDelete {
                        Button(L10n.tr("删除调弦"), role: .destructive, action: onDelete)
                    }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 30, height: 32)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 30)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var presetIcon: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(AppTheme.tint(for: preset.kind).opacity(0.11))

            InstrumentGlyph(kind: preset.kind)
                .frame(width: 18, height: 29)
        }
        .frame(width: 38, height: 38)
    }
}

/// 调音方式行：选择「按乐器调音」或「半音阶调音」。
struct TuningModeRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(isSelected ? AppTheme.accentSoft : AppTheme.controlBackground)

                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.secondaryText)
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer(minLength: 6)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// 主页乐器卡片顶部的调音模式快捷切换。
struct TuningModeSegmentedControl: View {
    let isFreeTuning: Bool
    let onSelectInstrument: () -> Void
    let onSelectChromatic: () -> Void

    var body: some View {
        HStack(spacing: 3) {
            segment(title: L10n.tr("乐器调音"),
                    isSelected: !isFreeTuning,
                    action: onSelectInstrument)
            segment(title: L10n.tr("半音阶"),
                    isSelected: isFreeTuning,
                    action: onSelectChromatic)
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.black.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.8)
        )
    }

    private func segment(title: String,
                         isSelected: Bool,
                         action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isSelected ? AppTheme.onAccent : AppTheme.secondaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .padding(.horizontal, 6)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isSelected
                              ? AnyShapeStyle(AppTheme.accentGradient)
                              : AnyShapeStyle(Color.clear))
                )
                .shadow(color: isSelected ? AppTheme.accent.opacity(0.35) : .clear,
                        radius: 6, x: 0, y: 2)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 分组卡片

struct InstrumentGroupCard<Content: View>: View {
    let title: String?
    @ViewBuilder let content: Content

    init(title: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .padding(.leading, 4)
            }

            VStack(spacing: 0) {
                content
            }
            .background(GlassCardBackground(cornerRadius: 18))
        }
    }
}

struct InstrumentRowDivider: View {
    var body: some View {
        Divider()
            .overlay(AppTheme.divider)
            .padding(.leading, 64)
    }
}
