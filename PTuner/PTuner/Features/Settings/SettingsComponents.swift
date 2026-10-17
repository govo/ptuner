import SwiftUI

struct SettingsSectionCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                content
            }
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
        }
    }
}

struct SettingsRow: View {
    let icon: String
    let iconTint: Color
    let title: String
    var value: String?
    var subtitle: String?
    var showsChevron: Bool = true
    var showsDivider: Bool = true

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(iconTint.opacity(0.13))

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(iconTint)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 8)

            if let value {
                Text(value)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if showsDivider {
                Divider()
                    .overlay(AppTheme.divider)
                    .padding(.leading, 57)
            }
        }
    }
}

extension View {
    /// 让整行设置项都可以点击。
    func settingsTappable() -> some View {
        self
            .contentShape(Rectangle())
            .buttonStyle(.plain)
    }

}
