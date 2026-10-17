import RevenueCatPaywallKit
import SwiftUI

/// 调音器主界面占位。当前阶段只搭好入口与基础服务，音频分析在后续迭代接入。
struct ContentView: View {
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager
    @Environment(\.openURL) private var openURL

    @State private var showsSettings = false
    @State private var showsComingSoon = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 20) {
                        tunerPanel
                        modePanel
                        proPanel
                    }
                    .padding(20)
                    .frame(maxWidth: 720)
                    .frame(maxWidth: .infinity)
                }
            }
            .navigationTitle("PTuner")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        AppAnalytics.track(.settingsOpened)
                        showsSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(width: 32, height: 32)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("设置")
                }
            }
            .sheet(isPresented: $showsSettings) {
                SettingsView()
                    .environmentObject(paywallManager)
            }
            .alert("即将上线", isPresented: $showsComingSoon) {
                Button("好", role: .cancel) {}
            } message: {
                Text("实时音高检测会在后续迭代接入。当前版本已完成基础服务与工程初始化。")
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - 调音面板

    private var tunerPanel: some View {
        VStack(spacing: 18) {
            Text("A4")
                .font(.system(size: 72, weight: .heavy, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .contentTransition(.numericText())

            Text("440.0 Hz")
                .font(.system(size: 18, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)

            centsGauge

            Text("0.0 cents")
                .font(.system(size: 16, weight: .semibold, design: .monospaced))
                .foregroundStyle(AppTheme.success)

            startTuningButton
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 28)
        .padding(.vertical, 36)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var centsGauge: some View {
        GeometryReader { geometry in
            let width = geometry.size.width

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.white.opacity(0.08))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [AppTheme.warning, AppTheme.success, AppTheme.warning],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: width * 0.22)
                    .offset(x: width * 0.39)

                Rectangle()
                    .fill(AppTheme.primaryText)
                    .frame(width: 2, height: 26)
                    .offset(x: width / 2 - 1)
            }
        }
        .frame(height: 26)
    }

    private var startTuningButton: some View {
        Button {
            AppAnalytics.track(.tunerStarted)
            AppDiagnostics.breadcrumb(.tuner, "start_tapped")
            showsComingSoon = true
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "play.fill")
                    .font(.system(size: 14, weight: .bold))
                Text("开始调音")
                    .font(.system(size: 17, weight: .bold))
            }
            .foregroundStyle(Color(red: 0.02, green: 0.08, blue: 0.10))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(AppTheme.accent)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 调音模式

    private var modePanel: some View {
        VStack(spacing: 12) {
            ProFeatureButton(
                manager: paywallManager,
                featureID: "multi_pitch",
                marketingMessage: "升级 Pro，解锁多音同时调音。"
            ) {
                AppDiagnostics.breadcrumb(.tuner, "multi_pitch_opened")
                showsComingSoon = true
            } label: {
                modeRow(
                    icon: "waveform",
                    title: "多音调音",
                    subtitle: "同时检测多根弦"
                )
            }

            ProFeatureButton(
                manager: paywallManager,
                featureID: "chord_recognition",
                marketingMessage: "升级 Pro，解锁实时和弦识别。"
            ) {
                AppDiagnostics.breadcrumb(.tuner, "chord_recognition_opened")
                showsComingSoon = true
            } label: {
                modeRow(
                    icon: "music.note.list",
                    title: "和弦识别",
                    subtitle: "显示当前和弦名称"
                )
            }
        }
    }

    private func modeRow(icon: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(AppTheme.accentSoft)
                    .frame(width: 48, height: 48)

                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surface)
        )
        .contentShape(Rectangle())
    }

    // MARK: - Pro 状态

    private var proPanel: some View {
        HStack(spacing: 14) {
            Image(systemName: paywallManager.hasActiveEntitlement ? "checkmark.seal.fill" : "crown.fill")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(paywallManager.hasActiveEntitlement ? AppTheme.success : AppTheme.warning)

            VStack(alignment: .leading, spacing: 3) {
                Text(paywallManager.hasActiveEntitlement ? "Pro 已激活" : "免费版")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(proDetail)
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 12)

            Button {
                if paywallManager.hasActiveEntitlement {
                    openURL(AppConfig.manageSubscriptionsURL)
                } else {
                    Task {
                        await paywallManager.presentPaywall(
                            featureID: "pro_panel",
                            marketingMessage: "解锁全部 Pro 功能。"
                        )
                    }
                }
            } label: {
                Text(paywallManager.hasActiveEntitlement ? "管理" : "升级 Pro")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var proDetail: String {
        guard paywallManager.hasActiveEntitlement else {
            return "多音调音、和弦识别与自定义调弦"
        }

        switch paywallManager.entitlementStatus {
        case .lifetime:
            return "永久权益"
        case .subscription(let expirationDate):
            return "订阅有效期至 \(expirationDate.formatted(date: .abbreviated, time: .omitted))"
        case .none:
            return "Pro 权益已激活"
        }
    }
}
