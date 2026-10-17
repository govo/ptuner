import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()

                ScrollView {
                    VStack(spacing: 18) {
                        hero
                        descriptionCard
                        linksCard
                        footer
                    }
                    .padding(.horizontal, 18)
                    .padding(.top, 14)
                    .padding(.bottom, 30)
                    .frame(maxWidth: 560)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle(L10n.tr("关于我们"))
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("完成")) { dismiss() }
                        .contentShape(Rectangle())
                }
            }
        }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.accentSoft)

                Image(systemName: "tuningfork")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 96, height: 96)

            Text("PTuner")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text(L10n.tr("专业乐器调音器"))
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)

            Text(versionText)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private var descriptionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(L10n.tr("为音乐爱好者和专业音乐人设计。支持单音调音、多音同时检测、和弦识别与任意弦数的自定义调弦。"))
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.primaryText)
                .lineSpacing(3)

            Text(L10n.tr("所有音高检测都在设备端完成，麦克风音频不会上传服务器。"))
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tunerCard(padding: 16)
    }

    private var linksCard: some View {
        InstrumentGroupCard {
            Button {
                openURL(AppConfig.privacyPolicyURL)
            } label: {
                linkRow(icon: "hand.raised.fill", tint: AppTheme.success, title: L10n.tr("隐私政策"), divider: true)
            }
            .buttonStyle(.plain)

            Button {
                openURL(AppConfig.termsOfUseURL)
            } label: {
                linkRow(icon: "doc.text.fill", tint: AppTheme.warning, title: L10n.tr("使用条款"), divider: false)
            }
            .buttonStyle(.plain)
        }
    }

    private func linkRow(icon: String, tint: Color, title: String, divider: Bool) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))

            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()

            Image(systemName: "arrow.up.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
        .overlay(alignment: .bottom) {
            if divider {
                Divider().overlay(AppTheme.divider).padding(.leading, 54)
            }
        }
    }

    private var footer: some View {
        Text("© 2026 PTuner. All rights reserved.")
            .font(.system(size: 11))
            .foregroundStyle(AppTheme.tertiaryText)
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return L10n.tr("版本 %@ (%@)", version, build)
    }
}
