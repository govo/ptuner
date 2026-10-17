import Combine
import RevenueCatPaywallKit
import SwiftUI

/// App 一级根视图：只负责 onboarding 分流与全局付费墙挂载。
struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager

    var body: some View {
        ZStack {
            AppBackground()

            Group {
                if hasCompletedOnboarding {
                    ContentView()
                        .transition(.opacity)
                } else {
                    LandingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                        .transition(.opacity)
                }
            }
        }
        // 本版只提供深色主题；亮色 token 保留，后续可再打开。
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.25), value: hasCompletedOnboarding)
        .revenueCatPaywallSheet(using: paywallManager)
        .onChange(of: paywallManager.isPaywallPresented) { _, isPresented in
            if isPresented {
                AppAnalytics.track(.paywallView, attributes: [
                    "feature": paywallManager.activePresentation.featureID ?? "unknown"
                ])
            }
        }
        .onReceive(paywallManager.$lastEventSource.dropFirst()) { source in
            guard let source, case .purchaseSuccess = source else { return }
            AppAnalytics.track(.purchase)
        }
    }
}
