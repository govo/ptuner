import RevenueCatPaywallKit
import SwiftUI

#if !os(macOS)
import UIKit
#endif

// MARK: - 非观察型环境注入

/// 只传递 TunerController 的引用，不订阅其 objectWillChange。
/// 需要调用控制器方法、但不展示实时数据的界面使用它，避免被监听高频刷新。
struct TunerControllerEnvironmentKey: EnvironmentKey {
    static let defaultValue: TunerController? = nil
}

extension EnvironmentValues {
    var tunerController: TunerController? {
        get { self[TunerControllerEnvironmentKey.self] }
        set { self[TunerControllerEnvironmentKey.self] = newValue }
    }
}

/// App 主容器：负责共享状态注入与一级导航。
struct ContentView: View {
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager
    @ObservedObject private var appLanguage = AppLanguageSettings.shared

    @StateObject private var tuner = TunerController()
    @StateObject private var library = InstrumentLibrary()
    @StateObject private var settings = TunerSettings()
    @StateObject private var router = AppRouter()

    var body: some View {
        GeometryReader { proxy in
            Group {
                #if os(macOS)
                splitLayout
                #else
                if usesWideLayout(for: proxy.size) {
                    splitLayout
                } else {
                    iosLayout
                }
                #endif
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.usesWideLayout, usesWideLayout(for: proxy.size))
        }
        .id(appLanguage.refreshID)
        .tint(AppTheme.accent)
        .environmentObject(tuner)
        // 高频实时读数单独注入：只有展示实时数据的页面观察它。
        .environmentObject(tuner.realtime)
        // 非观察型引用，供设置页等调用控制器方法而不订阅其变化。
        .environment(\.tunerController, tuner)
        .environmentObject(library)
        .environmentObject(settings)
        .environmentObject(router)
        .onChange(of: settings.stability) { _, _ in
            tuner.setDisplaySmoothing(settings.stability.smoothingFactor)
        }
        .task {
            #if DEBUG
            ScreenshotDemo.prepare(live: tuner.realtime, library: library)
            ScreenshotDemo.enterFullScreenIfNeeded()
            #endif
        }
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

    // MARK: - 宽屏双栏（macOS / 横屏 iPad）

    private var splitLayout: some View {
        NavigationSplitView {
            List(selection: tabSelection) {
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
                detailView
            }
        }
        .navigationSplitViewStyle(.balanced)
    }

    /// iOS 的 List(selection:) 只接受可选值；macOS 与 iPad 共用这一份绑定。
    private var tabSelection: Binding<MainTab?> {
        Binding(
            get: { router.selectedTab },
            set: { if let tab = $0 { router.selectedTab = tab } }
        )
    }

    @ViewBuilder
    private var detailView: some View {
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

    /// 横屏 iPad 使用侧边栏 + 内容；iPhone 与竖屏 iPad 保持底部标签栏。
    private func usesWideLayout(for size: CGSize) -> Bool {
        #if os(macOS)
        return true
        #else
        return UIDevice.current.userInterfaceIdiom == .pad && size.width > size.height
        #endif
    }
}
