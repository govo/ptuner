import Foundation
import Sentry

/// 埋点统一出口。
///
/// 业务代码只调用这里，不直接使用 `SentrySDK.metrics`，方便后续一键关闭或替换服务。
enum AppAnalytics {
    static let isEnabled = true

    enum Event: String {
        case appOpen = "app_open"
        case onboardingCompleted = "onboarding_completed"
        case paywallView = "paywall_view"
        case purchase = "purchase"
        case settingsOpened = "settings_opened"
        case restorePurchases = "restore_purchases"
        case tunerStarted = "tuner_started"
    }

    /// App 冷启动。必须放在 `SentrySDK.start` 之后调用；SDK 未启动时事件会被丢弃。
    static func appOpen() {
        track(.appOpen)
    }

    static func track(
        _ event: Event,
        attributes: [String: SentryAttributeValue] = [:]
    ) {
        guard isEnabled else { return }
        SentrySDK.metrics.count(key: event.rawValue, value: 1, attributes: attributes)
    }

    static func trackDistribution(
        _ key: String,
        value: Double,
        unit: SentryUnit? = nil,
        attributes: [String: SentryAttributeValue] = [:]
    ) {
        guard isEnabled else { return }
        SentrySDK.metrics.distribution(key: key, value: value, unit: unit, attributes: attributes)
    }
}
