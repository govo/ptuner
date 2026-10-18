import OnboardingFlowKit
import RevenueCatPaywallKit
import SwiftUI

/// 首次启动引导 / 落地页。使用公用组件 OnboardingFlowKit，内容按 PTuner 产品定位定制。
struct LandingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager

    var body: some View {
        OnboardingFlowView(
            pages: [
                .standard(
                    id: "tuning",
                    title: L10n.tr("一拨弦，就知道调没调准"),
                    subtitle: L10n.tr("音名、频率、音分偏差实时显示，不用再靠耳朵反复猜。"),
                    footnote: L10n.tr("支持 A4 参考音高与 0.1 音分精度。"),
                    titleColor: AppTheme.primaryText,
                    subtitleColor: AppTheme.secondaryText,
                    footnoteColor: AppTheme.tertiaryText
                ) {
                    heroIcon("tuningfork", tint: AppTheme.accent)
                },
                .standard(
                    id: "multi-pitch",
                    title: L10n.tr("一次拨弦，整琴看清"),
                    subtitle: L10n.tr("同时检测多根弦，哪根跑音一眼就知道，不用一根根来回试。"),
                    footnote: L10n.tr("多音调音为 Pro 功能。"),
                    titleColor: AppTheme.primaryText,
                    subtitleColor: AppTheme.secondaryText,
                    footnoteColor: AppTheme.tertiaryText
                ) {
                    heroIcon("waveform", tint: AppTheme.warning)
                },
                .standard(
                    id: "sweetened",
                    title: L10n.tr("找到你乐器的甜点调音"),
                    subtitle: L10n.tr("每把琴的共鸣都不同。微调每根弦的音分，让和弦落在最好听的位置。"),
                    footnote: L10n.tr("自定义弦数、音高与音分偏移，保存成你的专属调弦。"),
                    titleColor: AppTheme.primaryText,
                    subtitleColor: AppTheme.secondaryText,
                    footnoteColor: AppTheme.tertiaryText
                ) {
                    heroIcon("slider.horizontal.3", tint: AppTheme.success)
                }
            ],
            networkNoticePage: .networkNotice(
                configuration: OnboardingNetworkNoticeConfiguration(
                    heroSystemName: "lock.shield",
                    heroTint: AppTheme.success,
                    badgeTitle: L10n.tr("隐私优先"),
                    title: L10n.tr("调音在设备端完成"),
                    message: L10n.tr("麦克风音频只用于实时音高检测，不会上传服务器。"),
                    secondaryMessage: L10n.tr("仅在同步订阅状态时会访问网络。"),
                    items: [
                        OnboardingNetworkNoticeConfiguration.Item(
                            iconSystemName: "waveform",
                            iconTint: AppTheme.accent,
                            title: L10n.tr("本机处理"),
                            message: L10n.tr("音高检测在设备上运行。")
                        ),
                        OnboardingNetworkNoticeConfiguration.Item(
                            iconSystemName: "creditcard",
                            iconTint: AppTheme.warning,
                            title: L10n.tr("订阅同步"),
                            message: L10n.tr("App 会向 App Store 核对 Pro 权益状态。")
                        )
                    ]
                ),
                theme: onboardingTheme
            ),
            theme: onboardingTheme,
            navigation: OnboardingFlowNavigation(
                title: "PTuner",
                showsTitle: true,
                skipButtonTitle: L10n.tr("跳过"),
                nextButtonTitle: L10n.tr("继续"),
                doneButtonTitle: L10n.tr("开始调音"),
                nextButtonSystemImage: "arrow.right",
                doneButtonSystemImage: "waveform"
            ),
            behavior: OnboardingFlowBehavior(
                showsPageIndicator: true,
                allowsSkipToEnd: true,
                skipCompletesFlow: false
            ),
            onComplete: completeOnboarding
        )
    }

    private var onboardingTheme: OnboardingFlowTheme {
        OnboardingFlowTheme(
            backgroundColor: AppTheme.background,
            surfaceColor: AppTheme.surface,
            primaryColor: AppTheme.accent,
            onPrimaryColor: AppTheme.onAccent,
            titleColor: AppTheme.primaryText,
            bodyColor: AppTheme.secondaryText,
            secondaryTextColor: AppTheme.secondaryText,
            indicatorActiveColor: AppTheme.accent,
            indicatorInactiveColor: AppTheme.tertiaryText.opacity(0.3),
            skipButtonBackgroundColor: AppTheme.controlBackground,
            skipButtonForegroundColor: AppTheme.secondaryText,
            cardBackgroundColor: AppTheme.surfaceElevated,
            cardBorderColor: AppTheme.cardBorder,
            cardShadowColor: AppTheme.shadow
        )
    }

    private func heroIcon(_ systemName: String, tint: Color) -> some View {
        ZStack {
            Circle()
                .fill(tint.opacity(0.14))
                .frame(width: 132, height: 132)

            Circle()
                .fill(tint.opacity(0.08))
                .frame(width: 96, height: 96)

            Image(systemName: systemName)
                .font(.system(size: 50, weight: .light))
                .foregroundStyle(tint)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
    }

    private func completeOnboarding() {
        AppDiagnostics.breadcrumb(.onboarding, "completed")
        AppAnalytics.track(.onboardingCompleted)
        hasCompletedOnboarding = true

        Task {
            await paywallManager.presentPaywall(
                featureID: "onboarding",
                marketingMessage: L10n.tr("解锁多音调音与自定义调弦。")
            )
        }
    }
}
