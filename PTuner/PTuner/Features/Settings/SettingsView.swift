import AppSupportKit
import RevenueCatPaywallKit
import SwiftUI

/// 设置页。布局组件来自公用库 AppSupportKit，收益/评分/隐私入口在这里统一收敛。
struct SettingsView: View {
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager
    @EnvironmentObject private var reviewController: AppReviewPromptController
    @ObservedObject private var proAccess = ProAccessController.shared
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var isRestoring = false
    @State private var alertMessage: String?

    var body: some View {
        NavigationStack {
            AppSettingsScreen(backgroundColor: AppTheme.background) {
                header
            } content: {
                proSection
                supportSection
                aboutSection
                #if DEBUG
                debugProSection
                #endif
            }
            .navigationTitle("设置")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                    .contentShape(Rectangle())
                }
            }
            .alert(
                "提示",
                isPresented: Binding(
                    get: { alertMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            alertMessage = nil
                        }
                    }
                )
            ) {
                Button("好", role: .cancel) {}
            } message: {
                Text(alertMessage ?? "")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(AppTheme.accentSoft)
                    .frame(width: 56, height: 56)

                Image(systemName: "tuningfork")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("PTuner")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(versionText)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surface)
        )
    }

    // MARK: - Pro

    private var proSection: some View {
        AppSettingsSectionCard(
            backgroundColor: AppTheme.surface,
            shadowColor: Color.black.opacity(0.25)
        ) {
            VStack(spacing: 0) {
                AppSettingsRow(
                    icon: "crown.fill",
                    iconTint: proAccess.isPro(paywallManager) ? AppTheme.success : AppTheme.warning,
                    title: proAccess.isPro(paywallManager) ? "Pro 已激活" : "免费版",
                    subtitle: proDetail,
                    showsChevron: false,
                    showsDivider: true,
                    theme: rowTheme
                )

                Button {
                    if proAccess.isPro(paywallManager) {
                        openURL(AppConfig.manageSubscriptionsURL)
                    } else {
                        Task {
                            await paywallManager.presentPaywall(
                                featureID: "settings_upgrade",
                                marketingMessage: "解锁全部 Pro 功能。"
                            )
                        }
                    }
                } label: {
                    AppSettingsRow(
                        icon: proAccess.isPro(paywallManager) ? "arrow.up.right.circle.fill" : "sparkles",
                        iconTint: AppTheme.accent,
                        title: proAccess.isPro(paywallManager) ? "管理订阅" : "升级 Pro",
                        showsDivider: true,
                        theme: rowTheme
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                Button {
                    restorePurchases()
                } label: {
                    AppSettingsRow(
                        icon: "arrow.clockwise",
                        iconTint: AppTheme.secondaryText,
                        title: isRestoring ? "正在恢复…" : "恢复购买",
                        showsChevron: false,
                        theme: rowTheme
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
                .disabled(isRestoring)
            }
        }
    }

    private var proDetail: String {
        #if DEBUG
        if proAccess.skipsEntitlementCheck {
            return "Debug 模式已跳过权益校验"
        }
        #endif

        guard paywallManager.hasActiveEntitlement else {
            return "多音调音、和弦识别与自定义调弦"
        }

        switch paywallManager.entitlementStatus {
        case .lifetime:
            return "永久权益"
        case .subscription(let expirationDate):
            return "订阅有效期至 \(expirationDate.formatted(date: .abbreviated, time: .omitted))"
        case .none:
            return "Pro 权益已激活"
        }
    }

    private func restorePurchases() {
        guard !isRestoring else { return }
        isRestoring = true
        AppAnalytics.track(.restorePurchases)

        Task {
            await paywallManager.restorePurchases()
            isRestoring = false
            alertMessage = paywallManager.hasActiveEntitlement
                ? "已恢复购买。"
                : "没有找到可恢复的购买记录。"
        }
    }

    // MARK: - 支持

    private var supportSection: some View {
        AppSettingsSectionCard(
            backgroundColor: AppTheme.surface,
            shadowColor: Color.black.opacity(0.25)
        ) {
            VStack(spacing: 0) {
                Button {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        reviewController.presentManually(contextLabel: "settings")
                    }
                } label: {
                    AppSettingsRow(
                        icon: "star.fill",
                        iconTint: AppTheme.warning,
                        title: "给 PTuner 评分",
                        subtitle: "你的评价对我们很重要",
                        showsDivider: true,
                        theme: rowTheme
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                Button {
                    openURL(AppConfig.privacyPolicyURL)
                } label: {
                    AppSettingsRow(
                        icon: "hand.raised.fill",
                        iconTint: AppTheme.accent,
                        title: "隐私政策",
                        showsDivider: true,
                        theme: rowTheme
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())

                Button {
                    openURL(AppConfig.termsOfUseURL)
                } label: {
                    AppSettingsRow(
                        icon: "doc.text.fill",
                        iconTint: AppTheme.secondaryText,
                        title: "使用条款",
                        showsChevron: false,
                        theme: rowTheme
                    )
                }
                .buttonStyle(.plain)
                .contentShape(Rectangle())
            }
        }
    }

    // MARK: - 关于

    private var aboutSection: some View {
        AppSettingsSectionCard(
            backgroundColor: AppTheme.surface,
            shadowColor: Color.black.opacity(0.25)
        ) {
            AppSettingsRow(
                icon: "info.circle.fill",
                iconTint: AppTheme.secondaryText,
                title: "版本",
                subtitle: versionText,
                showsChevron: false,
                theme: rowTheme
            )
        }
    }

    // MARK: - 开发者（仅 Debug）

    #if DEBUG
    private var debugProSection: some View {
        AppSettingsSectionCard(
            backgroundColor: AppTheme.surface,
            shadowColor: Color.black.opacity(0.25)
        ) {
            HStack(spacing: 14) {
                Image(systemName: "ladybug.fill")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(AppTheme.warning)
                    .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: 3) {
                    Text("跳过 Pro 权益校验")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)

                    Text("仅 Debug 构建可用。开启后所有 Pro 功能直接可用，不再校验 RevenueCat 权益。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 12)

                Toggle("跳过 Pro 权益校验", isOn: $proAccess.skipsEntitlementCheck)
                    .labelsHidden()
                    .tint(AppTheme.accent)
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
    }
    #endif

    // MARK: - 辅助

    private var rowTheme: AppSettingsRowTheme {
        AppSettingsRowTheme(
            cardBackground: .clear,
            titleColor: AppTheme.primaryText,
            subtitleColor: AppTheme.secondaryText,
            chevronColor: AppTheme.secondaryText,
            dividerColor: Color.white.opacity(0.08),
            shadowColor: .clear
        )
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
