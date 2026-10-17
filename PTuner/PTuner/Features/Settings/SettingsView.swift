import AppSupportKit
import RevenueCatPaywallKit
import SwiftUI

/// 设置页：参考音高、显示精度、指示器样式、稳定度、音频输入与 Pro 信息。
struct SettingsView: View {
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager
    @EnvironmentObject private var reviewController: AppReviewPromptController
    @EnvironmentObject private var settings: TunerSettings
    @ObservedObject private var proAccess = ProAccessController.shared
    @ObservedObject private var languageSettings = AppLanguageSettings.shared
    #if os(macOS)
    @ObservedObject private var inputMonitor = AudioInputDeviceMonitor.shared
    #endif

    @Environment(\.openURL) private var openURL

    @State private var showsCustomPitchSheet = false
    @State private var showsAbout = false
    @State private var isRestoring = false
    @State private var alertMessage: String?
    @State private var activeOption: SettingsOption?

    private enum SettingsOption: String, Identifiable {
        case referencePitch
        case precision
        case indicatorStyle
        case stability

        var id: String { rawValue }

        var title: String {
            switch self {
            case .referencePitch: return L10n.tr("参考音高")
            case .precision: return L10n.tr("音准显示精度")
            case .indicatorStyle: return L10n.tr("指示器显示方式")
            case .stability: return L10n.tr("稳定度")
            }
        }
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    basicSection
                    languageSection
                    audioSection
                    proSection
                    otherSection
                    RecommendedAppsSection()
                    #if DEBUG
                    debugProSection
                    #endif
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 30)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(L10n.tr("设置"))
        .sheet(isPresented: $showsCustomPitchSheet) {
            ReferencePitchSheet(currentPitch: settings.referencePitch) { value in
                settings.setReferencePitch(value)
            }
        }
        .sheet(isPresented: $showsAbout) {
            AboutView()
        }
        .alert(
            L10n.tr("提示"),
            isPresented: Binding(
                get: { alertMessage != nil },
                set: { if !$0 { alertMessage = nil } }
            )
        ) {
            Button(L10n.tr("好"), role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
        .confirmationDialog(
            activeOption?.title ?? "",
            isPresented: Binding(
                get: { activeOption != nil },
                set: { if !$0 { activeOption = nil } }
            ),
            titleVisibility: .visible
        ) {
            optionActions
        }
    }

    // MARK: - 选项菜单

    @ViewBuilder
    private var optionActions: some View {
        switch activeOption {
        case .referencePitch:
            ForEach([432.0, 440.0, 442.0], id: \.self) { pitch in
                Button("A4 = \(Int(pitch)) Hz") {
                    settings.setReferencePitch(pitch)
                }
            }

            Divider()

            Button(L10n.tr("自定义…")) {
                openCustomPitchSheet()
            }

        case .precision:
            ForEach(CentsPrecision.allCases) { precision in
                Button(precision.title) {
                    settings.centsPrecision = precision
                }
            }

        case .indicatorStyle:
            ForEach(IndicatorStyle.allCases) { style in
                Button(style.title) {
                    settings.indicatorStyle = style
                }
            }

        case .stability:
            ForEach(DisplayStability.allCases) { stability in
                Button(stability.title) {
                    settings.stability = stability
                }
            }

        case nil:
            EmptyView()
        }

        Button(L10n.tr("取消"), role: .cancel) {}
    }

    private func openCustomPitchSheet() {
        activeOption = nil
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            showsCustomPitchSheet = true
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(AppTheme.accentSoft)

                Image(systemName: "tuningfork")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }
            .frame(width: 54, height: 54)

            VStack(alignment: .leading, spacing: 4) {
                Text("PTuner")
                    .font(.system(size: 21, weight: .bold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(versionText)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer()
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(AppTheme.cardBorder, lineWidth: 1)
        )
    }

    // MARK: - 基础设置

    private var basicSection: some View {
        SettingsSectionCard(title: L10n.tr("基础设置")) {
            optionRow(icon: "tuningfork",
                      iconTint: AppTheme.accent,
                      title: L10n.tr("参考音高"),
                      value: "A4 = \(referencePitchText) Hz",
                      option: .referencePitch)

            optionRow(icon: "number",
                      iconTint: AppTheme.accent,
                      title: L10n.tr("音准显示精度"),
                      value: settings.centsPrecision.title,
                      option: .precision)

            optionRow(icon: "gauge.with.dots.needle.33percent",
                      iconTint: AppTheme.success,
                      title: L10n.tr("指示器显示方式"),
                      value: settings.indicatorStyle.title,
                      option: .indicatorStyle)

            optionRow(icon: "waveform.path",
                      iconTint: AppTheme.warning,
                      title: L10n.tr("稳定度"),
                      value: settings.stability.title,
                      option: .stability,
                      showsDivider: false)
        }
    }

    // MARK: - 语言

    private var languageSection: some View {
        SettingsSectionCard(title: L10n.tr("语言")) {
            Menu {
                ForEach(AppLanguageSettings.options) { option in
                    Button {
                        languageSettings.select(option)
                    } label: {
                        if languageSettings.selectedCode == option.code {
                            Label(option.displayTitle, systemImage: "checkmark")
                        } else {
                            Text(option.displayTitle)
                        }
                    }
                }
            } label: {
                SettingsRow(icon: "globe",
                            iconTint: AppTheme.accent,
                            title: L10n.tr("语言"),
                            value: languageSettings.selectedTitle,
                            showsChevron: true,
                            showsDivider: false)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private func optionRow(icon: String,
                           iconTint: Color,
                           title: String,
                           value: String,
                           option: SettingsOption,
                           showsDivider: Bool = true) -> some View {
        Button {
            activeOption = option
        } label: {
            SettingsRow(icon: icon,
                        iconTint: iconTint,
                        title: title,
                        value: value,
                        showsChevron: false,
                        showsDivider: showsDivider)
        }
        .settingsTappable()
    }

    // MARK: - 音频输入

    @ViewBuilder
    private var audioSection: some View {
        SettingsSectionCard(title: L10n.tr("音频输入")) {
            #if os(macOS)
            NavigationLink {
                AudioInputDeviceView()
            } label: {
                SettingsRow(icon: "mic.fill",
                            iconTint: AppTheme.success,
                            title: L10n.tr("输入设备"),
                            value: audioInputValue,
                            showsDivider: false)
            }
            .settingsTappable()
            #else
            SettingsRow(icon: "mic.fill",
                        iconTint: AppTheme.success,
                        title: L10n.tr("音频输入来源"),
                        value: audioInputValue,
                        showsChevron: false,
                        showsDivider: false)
            #endif
        }
    }

    private var audioInputValue: String {
        #if os(macOS)
        if let uid = settings.preferredInputDeviceUID {
            if let device = inputMonitor.devices.first(where: { $0.id == uid }) {
                return device.name
            }
            return L10n.tr("设备不可用")
        }
        if let uid = inputMonitor.defaultDeviceUID,
           let device = inputMonitor.devices.first(where: { $0.id == uid }) {
            return L10n.tr("系统默认 · %@", device.name)
        }
        return L10n.tr("系统默认")
        #else
        return AudioInputDevices.currentInputName() ?? L10n.tr("系统麦克风")
        #endif
    }

    // MARK: - Pro

    private var proSection: some View {
        SettingsSectionCard(title: "Pro") {
            NavigationLink {
                ProInfoView()
            } label: {
                SettingsRow(icon: proAccess.isPro(paywallManager) ? "checkmark.seal.fill" : "crown.fill",
                            iconTint: proAccess.isPro(paywallManager) ? AppTheme.success : AppTheme.warning,
                            title: proAccess.isPro(paywallManager) ? L10n.tr("Pro 已激活") : L10n.tr("免费版"),
                            value: proDetail)
            }
            .settingsTappable()

            Button {
                restorePurchases()
            } label: {
                SettingsRow(icon: "arrow.clockwise",
                            iconTint: AppTheme.secondaryText,
                            title: isRestoring ? L10n.tr("正在恢复…") : L10n.tr("恢复购买"),
                            showsChevron: false,
                            showsDivider: false)
            }
            .settingsTappable()
            .disabled(isRestoring)
        }
    }

    private var proDetail: String {
        #if DEBUG
        if proAccess.skipsEntitlementCheck {
            return L10n.tr("Debug 已跳过校验")
        }
        #endif

        guard paywallManager.hasActiveEntitlement else {
            return L10n.tr("未升级")
        }

        switch paywallManager.entitlementStatus {
        case .lifetime:
            return L10n.tr("永久权益")
        case .subscription(let expirationDate):
            let style = Date.FormatStyle(date: .abbreviated, time: .omitted)
                .locale(Locale(identifier: L10n.effectiveCode))
            return L10n.tr("至 %@", expirationDate.formatted(style))
        case .none:
            return L10n.tr("已激活")
        }
    }

    private func restorePurchases() {
        guard !isRestoring else { return }
        isRestoring = true
        AppAnalytics.track(.restorePurchases)

        Task {
            await paywallManager.restorePurchases()
            isRestoring = false
            alertMessage = paywallManager.hasActiveEntitlement
                ? L10n.tr("已恢复购买。")
                : L10n.tr("没有找到可恢复的购买记录。")
        }
    }

    // MARK: - 其他

    private var otherSection: some View {
        SettingsSectionCard(title: L10n.tr("其他")) {
            SettingsRow(icon: "info.circle.fill",
                        iconTint: AppTheme.secondaryText,
                        title: L10n.tr("App 版本"),
                        value: versionText,
                        showsChevron: false)

            Button {
                showsAbout = true
            } label: {
                SettingsRow(icon: "music.note.list",
                            iconTint: AppTheme.accent,
                            title: L10n.tr("关于我们"))
            }
            .settingsTappable()

            Button {
                openURL(AppConfig.privacyPolicyURL)
            } label: {
                SettingsRow(icon: "hand.raised.fill",
                            iconTint: AppTheme.success,
                            title: L10n.tr("隐私政策"))
            }
            .settingsTappable()

            Button {
                openURL(AppConfig.termsOfUseURL)
            } label: {
                SettingsRow(icon: "doc.text.fill",
                            iconTint: AppTheme.warning,
                            title: L10n.tr("使用条款"))
            }
            .settingsTappable()

            Button {
                reviewController.presentManually(contextLabel: "settings")
            } label: {
                SettingsRow(icon: "star.fill",
                            iconTint: AppTheme.warning,
                            title: L10n.tr("给 %@ 评分", "PTuner"),
                            showsChevron: false,
                            showsDivider: false)
            }
            .settingsTappable()
        }
    }

    // MARK: - Debug

    #if DEBUG
    private var debugProSection: some View {
        SettingsSectionCard(title: L10n.tr("开发者")) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(AppTheme.warning.opacity(0.13))

                    Image(systemName: "ladybug.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.warning)
                }
                .frame(width: 30, height: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(L10n.tr("跳过 Pro 权益校验"))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)

                    Text(L10n.tr("仅 Debug 构建可用，方便直接测试 Pro 功能。"))
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                Toggle(L10n.tr("跳过 Pro 权益校验"), isOn: $proAccess.skipsEntitlementCheck)
                    .labelsHidden()
                    .tint(AppTheme.accent)
                    .contentShape(Rectangle())
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
        }
    }
    #endif

    // MARK: - 辅助

    private var referencePitchText: String {
        let rounded = (settings.referencePitch * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }

    private var versionText: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}
