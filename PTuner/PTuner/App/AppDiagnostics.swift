import Foundation
import Sentry

/// 崩溃与异常诊断统一出口。与 `AppAnalytics` 分工：
/// - `AppAnalytics` 只发计数 / 分布指标；
/// - `AppDiagnostics` 只发面包屑与非致命错误，服务于崩溃排查。
enum AppDiagnostics {
    static let isEnabled = true

    enum Flow: String {
        case app = "app"
        case onboarding = "onboarding"
        case purchase = "purchase"
        case settings = "settings"
        case tuner = "tuner"
    }

    static func breadcrumb(
        _ flow: Flow,
        _ step: String,
        data: [String: Any] = [:]
    ) {
        guard isEnabled else { return }

        let crumb = Breadcrumb(level: .info, category: flow.rawValue)
        crumb.message = step
        for (key, value) in data {
            crumb.setData(value: value, key: key)
        }
        SentrySDK.addBreadcrumb(crumb)
    }

    static func capture(
        _ error: Error,
        flow: Flow,
        tags: [String: String] = [:],
        extra: [String: Any] = [:]
    ) {
        guard isEnabled else { return }

        SentrySDK.capture(error: error) { scope in
            scope.setTag(value: flow.rawValue, key: "app_flow")
            for (key, value) in tags {
                scope.setTag(value: value, key: key)
            }
            for (key, value) in extra {
                scope.setExtra(value: value, key: key)
            }
        }
    }
}
