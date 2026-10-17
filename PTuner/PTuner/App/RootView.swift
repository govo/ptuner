import Combine
import RevenueCatPaywallKit
import SwiftUI

/// App 一级根视图：只负责 onboarding 分流与全局付费墙挂载。
struct RootView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

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
