import Foundation
import RevenueCatPaywallKit

/// 基础服务配置。
///
/// 当前为初始化阶段，RevenueCat 与 Sentry 均使用占位值：
/// - RevenueCat 占位 key 会让 SDK 初始化失败，但按公用库的设计会静默降级，不影响免费功能；
/// - Sentry DSN 为空时不启动 SDK。
/// 拿到真实值后，只需要替换本文件中的常量。
enum AppConfig {
    enum RevenueCat {
        static let entitlementID = "ptuner_pro"
        static let apiKeyDebug = "test_jiadKsBHZcJGCigTZcsxzGRlZaj"
        static let apiKeyRelease = "appl_nbraQyYMEVtzUcQqcYQmRAFFyhI"
        static let offeringID = "default"
    }

    enum Sentry {
        /// 留空表示不初始化 Sentry。
        static let dsn = ""
    }

    static var revenueCatConfiguration: RevenueCatPaywallConfiguration {
        RevenueCatPaywallConfiguration(
            entitlementID: RevenueCat.entitlementID,
            apiKeys: RevenueCatClientKeys(
                debug: RevenueCat.apiKeyDebug,
                release: RevenueCat.apiKeyRelease
            ),
            offering: RevenueCatOfferingConfiguration(
                preferredOfferingID: RevenueCat.offeringID
            ),
            enablesDebugLogs: {
                #if DEBUG
                true
                #else
                false
                #endif
            }()
        )
    }

    static let privacyPolicyURL = URL(string: "https://example.com/privacy")!
    static let termsOfUseURL = URL(string: "https://example.com/terms")!
    static let manageSubscriptionsURL = URL(string: "https://apps.apple.com/account/subscriptions")!
}
