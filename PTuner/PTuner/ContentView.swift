import RevenueCatPaywallKit
import SwiftUI

/// App 主容器：负责共享状态注入与一级导航。
struct ContentView: View {
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager

    @StateObject private var tuner = TunerController()
    @StateObject private var library = InstrumentLibrary()
    @StateObject private var settings = TunerSettings()
    @StateObject private var router = AppRouter()

    var body: some View {
        Group {
            #if os(macOS)
            macLayout
            #else
            iosLayout
            #endif
        }
        .tint(AppTheme.accent)
        .environmentObject(tuner)
        .environmentObject(library)
        .environmentObject(settings)
        .environmentObject(router)
    }

    // MARK: - iOS

    #if !os(macOS)
    private var iosLayout: some View {
        TabView(selection: $router.selectedTab) {
            NavigationStack {
                TunerHomeView()
            }
            .tabItem {
                Label(MainTab.tuner.title, systemImage: MainTab.tuner.systemImage)
            }
            .tag(MainTab.tuner)

            NavigationStack {
                ChordRecognitionView()
            }
            .tabItem {
                Label(MainTab.chord.title, systemImage: MainTab.chord.systemImage)
            }
            .tag(MainTab.chord)

            NavigationStack {
                InstrumentSelectionView()
            }
            .tabItem {
                Label(MainTab.instruments.title, systemImage: MainTab.instruments.systemImage)
            }
            .tag(MainTab.instruments)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label(MainTab.settings.title, systemImage: MainTab.settings.systemImage)
            }
            .tag(MainTab.settings)
        }
    }
    #endif

    // MARK: - macOS

    #if os(macOS)
    private var macLayout: some View {
        NavigationSplitView {
            List(selection: $router.selectedTab) {
                Section("PTuner") {
                    ForEach(MainTab.allCases) { tab in
                        Label(tab.title, systemImage: tab.systemImage)
                            .tag(tab)
                    }
                }
            }
            .listStyle(.sidebar)
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 260)
        } detail: {
            NavigationStack {
                switch router.selectedTab {
                case .tuner:
                    TunerHomeView()
                case .chord:
                    ChordRecognitionView()
                case .instruments:
                    InstrumentSelectionView()
                case .settings:
                    SettingsView()
                }
            }
        }
        .navigationSplitViewStyle(.balanced)
    }
    #endif
}
