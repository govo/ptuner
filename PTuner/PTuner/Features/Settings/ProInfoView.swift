import RevenueCatPaywallKit
import SwiftUI

struct ProInfoView: View {
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager
    @ObservedObject private var proAccess = ProAccessController.shared
    @Environment(\.openURL) private var openURL

    @State private var isRestoring = false
    @State private var alertMessage: String?

    private var isPro: Bool {
        proAccess.isPro(paywallManager)
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 16) {
                    heroCard
                    featureCard
                    statusCard
                    restoreRow
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 30)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(L10n.tr("Pro 信息"))
        .alert(
            L10n.tr("提示"),
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button(L10n.tr("好"), role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    // MARK: - Hero

    private var heroCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.18))

                    Image(systemName: "crown.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(Color.white)
                }
                .frame(width: 50, height: 50)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(L10n.tr("专业版"))
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(Color.white)

                        Text("Pro")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.22))
                            .clipShape(Capsule())
                    }

                    Text(isPro ? L10n.tr("Pro 权益已激活") : L10n.tr("解锁更多高级功能，提升调音体验"))
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.85))
                }

                Spacer()
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(
                colors: [AppTheme.accent, AppTheme.accent.opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: AppTheme.accent.opacity(0.28), radius: 14, x: 0, y: 6)
    }

    // MARK: - 功能

    private var featureCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text(L10n.tr("Pro 功能"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            featureRow(L10n.tr("多音调音（最多 12 个音）"))
            featureRow(L10n.tr("实时和弦识别"))
            featureRow(L10n.tr("任意弦数的自定义调弦"))
            featureRow(L10n.tr("更高精度的音准显示"))
            featureRow(L10n.tr("更多专业功能"))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tunerCard(padding: 18)
    }

    private func featureRow(_ title: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(AppTheme.success)
                .frame(width: 20, height: 20)
                .background(AppTheme.success.opacity(0.12))
                .clipShape(Circle())

            Text(title)
                .font(.system(size: 14))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()
        }
    }

    // MARK: - 状态

    @ViewBuilder
    private var statusCard: some View {
        if isPro {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(AppTheme.success)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(L10n.tr("Pro 已激活"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        Text(entitlementTypeText)
                            .font(.system(size: 12))
                            .foregroundStyle(AppTheme.secondaryText)
                    }

                    Spacer()
                }

                if let expirationText {
                    Divider().overlay(AppTheme.divider)

                    HStack {
                        Text(L10n.tr("有效期"))
                            .font(.system(size: 13))
                            .foregroundStyle(AppTheme.secondaryText)
                        Spacer()
                        Text(expirationText)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(AppTheme.primaryText)
                    }
                }

                PrimaryTunerButton(title: L10n.tr("管理订阅"),
                                   systemImage: "arrow.up.right",
                                   role: .secondary) {
                    openURL(AppConfig.manageSubscriptionsURL)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .tunerCard(padding: 18)
        } else {
            VStack(spacing: 12) {
                PrimaryTunerButton(title: L10n.tr("升级 Pro"), systemImage: "crown.fill") {
                    Task {
                        await paywallManager.presentPaywall(
                            featureID: "pro_info",
                            marketingMessage: L10n.tr("解锁多音调音、和弦识别与自定义调弦。")
                        )
                    }
                }

                Text(L10n.tr("升级后可随时通过 App Store 管理或取消订阅。"))
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .tunerCard(padding: 16)
        }
    }

    private var restoreRow: some View {
        Button {
            restorePurchases()
        } label: {
            Text(isRestoring ? L10n.tr("正在恢复购买…") : L10n.tr("恢复购买"))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.accent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isRestoring)
    }

    // MARK: - 权益文案

    private var entitlementTypeText: String {
        #if DEBUG
        if proAccess.skipsEntitlementCheck && !paywallManager.hasActiveEntitlement {
            return L10n.tr("Debug 模式已跳过权益校验")
        }
        #endif

        guard paywallManager.hasActiveEntitlement else { return L10n.tr("未检测到有效权益") }

        switch paywallManager.entitlementStatus {
        case .lifetime:
            return L10n.tr("永久权益")
        case .subscription:
            if let willRenew = paywallManager.entitlementDetails?.willRenew {
                return willRenew ? L10n.tr("自动续订订阅") : L10n.tr("订阅（已关闭自动续订）")
            }
            return L10n.tr("订阅权益")
        case .none:
            return L10n.tr("Pro 权益已激活")
        }
    }

    private var expirationText: String? {
        guard case .subscription(let date) = paywallManager.entitlementStatus else {
            return nil
        }
        let style = Date.FormatStyle(date: .abbreviated, time: .omitted)
            .locale(Locale(identifier: L10n.effectiveCode))
        return date.formatted(style)
    }

    private func restorePurchases() {
        guard !isRestoring else { return }
        isRestoring = true
        AppAnalytics.track(.restorePurchases)

        Task {
            await paywallManager.restorePurchases()
            isRestoring = false
            alertMessage = paywallManager.hasActiveEntitlement
                ? L10n.tr("已恢复购买。")
                : L10n.tr("没有找到可恢复的购买记录。")
        }
    }
}
