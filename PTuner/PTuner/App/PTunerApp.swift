import AppSupportKit
import RevenueCatPaywallKit
import Sentry
import SwiftUI

@main
struct PTunerApp: App {
    @StateObject private var paywallManager: RevenueCatPaywallManager
    @StateObject private var reviewController: AppReviewPromptController

    init() {
        Self.configureSentry()
        AppAnalytics.appOpen()

        _paywallManager = StateObject(
            wrappedValue: RevenueCatPaywallManager(
                configuration: AppConfig.revenueCatConfiguration
            )
        )
        _reviewController = StateObject(
            wrappedValue: AppReviewPromptController(
                policy: AppReviewPromptPolicy(
                    automaticPromptThreshold: 3,
                    cooldownDays: 10,
                    storagePrefix: "ptuner.reviewPrompt"
                )
            )
        )
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(paywallManager)
                .environmentObject(reviewController)
                .appReviewPromptPresenter(
                    controller: reviewController,
                    configuration: AppReviewPromptConfiguration.ptuner,
                    theme: AppReviewPromptTheme.ptuner
                )
                #if os(macOS)
                .frame(minWidth: 860, minHeight: 620)
                #else
                .frame(minWidth: 420, minHeight: 640)
                #endif
                .task {
                    await paywallManager.start()
                }
        }
        #if os(macOS)
        .defaultSize(width: 1080, height: 740)
        .windowResizability(.contentMinSize)
        #endif
    }

    // MARK: - Sentry

    private static func configureSentry() {
        guard !AppConfig.Sentry.dsn.isEmpty else {
            AppDiagnostics.breadcrumb(.app, "sentry_skipped_missing_dsn")
            return
        }

        SentrySDK.start { options in
            options.dsn = AppConfig.Sentry.dsn

            // 只做崩溃与错误上报；性能监控显式关闭。
            options.tracesSampleRate = 0

            options.attachStacktrace = true
            options.enableWatchdogTerminationTracking = true
            options.enableAppHangTracking = true

            #if DEBUG
            options.environment = "debug"
            #else
            options.environment = "production"
            #endif
        }
    }
}

// MARK: - Review Prompt 文案

extension AppReviewPromptConfiguration {
    static var ptuner: AppReviewPromptConfiguration {
        AppReviewPromptConfiguration(
            title: { context in
                context.source == .automatic ? L10n.tr("喜欢 PTuner 吗？") : L10n.tr("支持 PTuner")
            },
            message: { _ in
                L10n.tr("如果 PTuner 对你的练习和演出有帮助，欢迎留下一个评分。")
            },
            detailText: { context in
                context.detailText ?? L10n.tr("已完成 %d 次调音", context.completedMilestoneCount)
            },
            badges: { _ in
                [
                    AppReviewPromptBadge(iconSystemName: "lock.shield", title: L10n.tr("端侧处理")),
                    AppReviewPromptBadge(iconSystemName: "star.bubble", title: L10n.tr("感谢支持"))
                ]
            },
            primaryButtonTitle: L10n.tr("去评分"),
            secondaryButtonTitle: L10n.tr("写评论"),
            secondaryLoadingTitle: L10n.tr("正在打开 App Store…"),
            laterButtonTitle: L10n.tr("以后再说"),
            lookupFailureMessage: L10n.tr("暂时无法打开 App Store 评分页。"),
            openFailureMessage: L10n.tr("无法在本设备上打开 App Store。")
        )
    }
}

extension AppReviewPromptTheme {
    static var ptuner: AppReviewPromptTheme {
        AppReviewPromptTheme(
            overlayColor: Color.black.opacity(0.45),
            heroBackground: AppTheme.accentSoft,
            heroForeground: AppTheme.accent,
            cardBackground: AppTheme.surfaceElevated,
            cardBorder: AppTheme.cardBorder,
            titleColor: AppTheme.primaryText,
            messageColor: AppTheme.secondaryText,
            detailBackground: AppTheme.accentSoft,
            detailForeground: AppTheme.accent,
            primaryButtonBackground: AppTheme.accent,
            primaryButtonForeground: AppTheme.onAccent,
            secondaryButtonBackground: AppTheme.controlBackground,
            secondaryButtonForeground: AppTheme.primaryText,
            secondaryButtonBorder: AppTheme.cardBorder,
            tertiaryButtonForeground: AppTheme.secondaryText,
            badgeBackground: AppTheme.controlBackground,
            badgeForeground: AppTheme.primaryText,
            badgeIconTint: AppTheme.accent,
            shadowColor: AppTheme.shadow
        )
    }
}
