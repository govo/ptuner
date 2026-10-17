import SwiftUI

/// 设置页底部的自家 App 推荐。点击后打开对应 App Store 页面。
struct RecommendedApp: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let appStoreURL: URL

    /// 每次访问都重新取译文：语言切换后根视图会重建，静态缓存会保留旧语言。
    static var all: [RecommendedApp] {
        [
            RecommendedApp(id: "splitjam",
                           title: "SplitJam",
                           subtitle: L10n.tr("在 App Store 中查看"),
                           icon: "slider.horizontal.3",
                           tint: AppTheme.accent,
                           appStoreURL: URL(string: "https://apps.apple.com/app/id6765638522")!),
            RecommendedApp(id: "drumai",
                           title: L10n.tr("鼓AI"),
                           subtitle: L10n.tr("在 App Store 中查看"),
                           icon: "waveform",
                           tint: AppTheme.warning,
                           appStoreURL: URL(string: "https://apps.apple.com/app/id6782609749")!),
            RecommendedApp(id: "metronome",
                           title: L10n.tr("节拍器大师"),
                           subtitle: L10n.tr("在 App Store 中查看"),
                           icon: "metronome",
                           tint: AppTheme.success,
                           appStoreURL: URL(string: "https://apps.apple.com/app/id6739794215")!)
        ]
    }
}

struct RecommendedAppsSection: View {
    @Environment(\.openURL) private var openURL

    var body: some View {
        let apps = RecommendedApp.all

        SettingsSectionCard(title: L10n.tr("更多 App")) {
            ForEach(Array(apps.enumerated()), id: \.element.id) { index, app in
                Button {
                    openURL(app.appStoreURL)
                } label: {
                    SettingsRow(icon: app.icon,
                                iconTint: app.tint,
                                title: app.title,
                                subtitle: app.subtitle,
                                showsChevron: true,
                                showsDivider: index < apps.count - 1)
                }
                .settingsTappable()
            }
        }
    }
}
