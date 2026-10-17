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
                    title: "专业级音准反馈",
                    subtitle: "实时显示音名、频率与 cents 偏差，像专业调音单块一样快速锁定音准。",
                    footnote: "支持 A4 参考音高与显示精度设置。",
                    titleColor: AppTheme.primaryText,
                    subtitleColor: AppTheme.secondaryText,
                    footnoteColor: AppTheme.tertiaryText
                ) {
                    heroIcon("tuningfork", tint: AppTheme.accent)
                },
                .standard(
                    id: "multi-pitch",
                    title: "多音与和弦识别",
                    subtitle: "同时检测多根弦，或直接识别当前和弦名称，适合快速校音与演奏辅助。",
                    footnote: "多音调音与和弦识别为 Pro 功能。",
                    titleColor: AppTheme.primaryText,
                    subtitleColor: AppTheme.secondaryText,
                    footnoteColor: AppTheme.tertiaryText
                ) {
                    heroIcon("waveform", tint: AppTheme.warning)
                },
                .standard(
                    id: "custom",
                    title: "为你的乐器而设",
                    subtitle: "内置吉他、贝斯、尤克里里等调弦，也可以创建任意弦数和音高的自定义调弦。",
                    footnote: "收藏常用调弦，打开即可调音。",
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
                    badgeTitle: "隐私优先",
                    title: "调音在设备端完成",
                    message: "麦克风音频只用于实时音高检测，不会上传服务器。",
                    secondaryMessage: "仅在同步订阅状态时会访问网络。",
                    items: [
                        OnboardingNetworkNoticeConfiguration.Item(
                            iconSystemName: "waveform",
                            iconTint: AppTheme.accent,
                            title: "本机处理",
                            message: "音高检测与和弦识别都在设备上运行。"
                        ),
                        OnboardingNetworkNoticeConfiguration.Item(
                            iconSystemName: "creditcard",
                            iconTint: AppTheme.warning,
                            title: "订阅同步",
                            message: "App 会向 App Store 核对 Pro 权益状态。"
                        )
                    ]
                ),
                theme: onboardingTheme
            ),
            theme: onboardingTheme,
            navigation: OnboardingFlowNavigation(
                title: "PTuner",
                showsTitle: true,
                skipButtonTitle: "跳过",
                nextButtonTitle: "继续",
                doneButtonTitle: "开始调音",
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
                marketingMessage: "解锁多音调音、和弦识别与自定义调弦。"
            )
        }
    }
}
