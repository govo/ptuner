import RevenueCatPaywallKit
import SwiftUI

// MARK: - 会员卡片

/// 设置页 Pro 区块顶部的会员卡片，展示当前用户的权益状态。
struct ProMembershipCard: View {
    let isPro: Bool
    let subtitle: String
    let badgeTitle: String

    private var tint: Color {
        isPro ? AppTheme.success : AppTheme.warning
    }

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                Circle()
                    .fill(tint.opacity(0.14))

                Image(systemName: isPro ? "checkmark.seal.fill" : "crown.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(isPro ? L10n.tr("Pro 用户") : L10n.tr("免费用户"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(2)
            }

            Spacer(minLength: 8)

            Text(badgeTitle)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(isPro ? AppTheme.success : AppTheme.onAccent)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    Capsule()
                        .fill(isPro ? AppTheme.success.opacity(0.14) : AppTheme.accent)
                )
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }
}

// MARK: - 权益详情

/// 只读的 Pro 权益详情：会员类型、到期日期、自动续订与产品标识。
struct ProEntitlementSheet: View {
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @ObservedObject private var proAccess = ProAccessController.shared

    private var details: RevenueCatEntitlementDetails? {
        paywallManager.entitlementDetails
    }

    var body: some View {
        VStack(spacing: 0) {
            header

            if let details {
                detailCard(details)
                    .padding(.horizontal, 24)
            } else {
                Text(debugSkipNote)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }

            Spacer(minLength: 24)

            actions
                .padding(.horizontal, 24)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(AppBackground())
        #if os(macOS)
        .frame(width: 400, height: 480)
        #else
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
    }

    // MARK: 头部

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.accent, AppTheme.accent.opacity(0.7)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                Image(systemName: "crown.fill")
                    .font(.system(size: 25, weight: .bold))
                    .foregroundStyle(Color.white)
            }
            .frame(width: 62, height: 62)
            .shadow(color: AppTheme.accent.opacity(0.35), radius: 12, x: 0, y: 5)

            Text(L10n.tr("Pro 会员详情"))
                .font(.system(size: 21, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)
        }
        .padding(.top, 30)
        .padding(.bottom, 24)
    }

    // MARK: 详情行

    private func detailCard(_ details: RevenueCatEntitlementDetails) -> some View {
        VStack(spacing: 0) {
            detailRow(title: L10n.tr("会员类型"),
                      value: membershipTypeText(details.kind))

            Divider().overlay(AppTheme.divider)

            detailRow(title: L10n.tr("到期日期"),
                      value: expirationText(details.kind))

            if case .subscription = details.kind {
                Divider().overlay(AppTheme.divider)

                detailRow(title: L10n.tr("自动续订"),
                          value: details.willRenew
                          ? L10n.tr("自动续订已开启")
                          : L10n.tr("自动续订已关闭"))
            }

            if let product = details.productIdentifier, !product.isEmpty {
                Divider().overlay(AppTheme.divider)

                detailRow(title: L10n.tr("产品标识"), value: product)
            }
        }
        .background(GlassCardBackground(cornerRadius: 20))
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer(minLength: 8)

            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
    }

    // MARK: 操作

    private var actions: some View {
        VStack(spacing: 12) {
            if case .subscription = paywallManager.entitlementStatus {
                PrimaryTunerButton(title: L10n.tr("管理订阅"),
                                   systemImage: "arrow.up.right",
                                   role: .secondary) {
                    openURL(AppConfig.manageSubscriptionsURL)
                }
            }

            Button {
                dismiss()
            } label: {
                Text(L10n.tr("关闭"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.onAccent)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(AppTheme.accentGradient)
                    )
                    .shadow(color: AppTheme.accent.opacity(0.4), radius: 12, x: 0, y: 5)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: 文案

    private var debugSkipNote: String {
        #if DEBUG
        if proAccess.skipsEntitlementCheck {
            return L10n.tr("Debug 模式已跳过权益校验")
        }
        #endif
        return L10n.tr("未检测到有效权益")
    }

    private func membershipTypeText(_ kind: RevenueCatEntitlementStatus) -> String {
        switch kind {
        case .none:
            return L10n.tr("免费用户")
        case .lifetime:
            return L10n.tr("永久权益")
        case .subscription:
            return L10n.tr("订阅权益")
        }
    }

    private func expirationText(_ kind: RevenueCatEntitlementStatus) -> String {
        switch kind {
        case .lifetime:
            return L10n.tr("永久")
        case .subscription(let date):
            let style = Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(Locale(identifier: L10n.effectiveCode))
            return date.formatted(style)
        case .none:
            return "—"
        }
    }
}
