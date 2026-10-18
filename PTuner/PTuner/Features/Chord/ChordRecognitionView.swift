import RevenueCatPaywallKit
import SwiftUI

/// 和弦识别是独立功能：只依赖多音检测结果，不读取当前乐器或调弦配置。
struct ChordRecognitionView: View {
    @EnvironmentObject private var tuner: TunerController
    @EnvironmentObject private var live: TunerRealtimeState
    @EnvironmentObject private var settings: TunerSettings
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager
    @ObservedObject private var proAccess = ProAccessController.shared
    @ObservedObject private var quota = FreeUsageQuota.shared

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.usesWideLayout) private var usesWideLayout
    /// 和弦识别必须由用户主动开始，进入页面不自动监听。
    @State private var isChordListening = false
    @State private var lastPolyAnalyzedSeconds: Double = 0
    @State private var quotaAlert: FreeUsageQuota.Limit?

    private var proUnlocked: Bool {
        proAccess.isPro(paywallManager)
    }

    /// 免费用户的每日 / 每周额度用尽后，整页切换为 Pro 锁。
    private var chordLocked: Bool {
        !proUnlocked && quota.chordExhaustion != nil
    }

    private var chordRows: [PolyStringReading] {
        guard isChordListening else { return [] }
        return PolyReadingBuilder.build(readouts: live.polyReadouts,
                                        referencePitch: 440,
                                        preset: nil)
            .sorted { $0.midiPitch < $1.midiPitch }
    }

    private var chordMatch: ChordMatch? {
        guard isChordListening else { return nil }
        return ChordRecognizer.recognize(pitchClasses: live.polyReadouts.map(\.midiPitch))
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 14) {
                    header
                    statusBanners

                    if chordLocked {
                        lockedCard
                    } else {
                        contentLayout
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
        }
        .onAppear {
            #if DEBUG
            if ScreenshotDemo.scene == .chord {
                // 截图演示：直接进入监听状态，读数由启动参数注入。
                isChordListening = true
                lastPolyAnalyzedSeconds = live.polyAnalyzedSeconds
                return
            }
            #endif
            quota.refreshNow()
            lastPolyAnalyzedSeconds = live.polyAnalyzedSeconds
        }
        .onDisappear {
            stopChordListening()
        }
        .onChange(of: proUnlocked) { _, _ in
            syncChordDemand()
        }
        .onChange(of: router.selectedTab) { _, tab in
            guard tab == .chord else {
                stopChordListening()
                return
            }
            syncChordDemand()
        }
        .onChange(of: tuner.isRunning) { _, running in
            guard running else {
                isChordListening = false
                tuner.setChordRecognitionActive(false)
                return
            }
            syncChordDemand()
        }
        .onChange(of: tuner.isStarting) { _, starting in
            // 启动失败（无权限、设备错误）时回到未开始状态。
            if !starting, !tuner.isRunning {
                isChordListening = false
                tuner.setChordRecognitionActive(false)
            }
        }
        .onChange(of: live.polyAnalyzedSeconds) { _, seconds in
            defer { lastPolyAnalyzedSeconds = seconds }
            guard isChordListening,
                  router.selectedTab == .chord,
                  !chordLocked,
                  tuner.isRunning,
                  tuner.polyphonicEnabled,
                  !proUnlocked else { return }

            let delta = seconds - lastPolyAnalyzedSeconds
            // 重置或异常跳变不计入额度。
            guard delta > 0, delta < 5 else { return }
            quota.record(.chordRecognition, seconds: delta)
        }
        .onChange(of: quota.chordExhaustion) { _, limit in
            guard let limit else {
                // 跨日 / 跨周重置后恢复可用。
                syncChordDemand()
                return
            }

            // 到限额立即停止识别，并切换到锁定状态。
            isChordListening = false
            tuner.setChordRecognitionActive(false)
            guard !proUnlocked else { return }
            quotaAlert = limit
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            quota.refreshNow()
            syncChordDemand()
        }
        .alert(
            quotaAlert?.title ?? "",
            isPresented: Binding(
                get: { quotaAlert != nil },
                set: { if !$0 { quotaAlert = nil } }
            )
        ) {
            Button(L10n.tr("升级 Pro")) {
                quotaAlert = nil
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(250))
                    presentPaywall()
                }
            }

            Button(L10n.tr("以后再说"), role: .cancel) {
                quotaAlert = nil
            }
        } message: {
            Text(quotaAlert?.message(for: .chordRecognition) ?? "")
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            Text(L10n.tr("和弦识别"))
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Spacer(minLength: 8)

            #if os(macOS)
            TunerHeaderInputStatus(deviceName: tuner.activeInputDeviceName,
                                   level: isChordListening ? live.level : 0,
                                   isRunning: isChordListening,
                                   selectedDeviceUID: settings.preferredInputDeviceUID,
                                   onSelectDevice: selectInputDevice)
                .layoutPriority(1)
            #else
            TunerHeaderInputStatus(deviceName: tuner.activeInputDeviceName,
                                   level: isChordListening ? live.level : 0,
                                   isRunning: isChordListening)
                .layoutPriority(1)
            #endif
        }
    }

    #if os(macOS)
    /// 在右上角直接切换输入设备，与调音页、设置页共用同一条持久化链路。
    private func selectInputDevice(_ uid: String?) {
        guard uid != settings.preferredInputDeviceUID else { return }
        settings.preferredInputDeviceUID = uid
        settings.apply(to: tuner)
    }
    #endif

    @ViewBuilder
    private var contentLayout: some View {
        if usesWideLayout {
            HStack(alignment: .top, spacing: 18) {
                chordPanel
                    .frame(maxWidth: .infinity)
                chordControlCard
                    .frame(width: 310)
            }
        } else {
            VStack(spacing: 14) {
                chordPanel
                chordControlCard
            }
        }
    }

    @ViewBuilder
    private var statusBanners: some View {
        if tuner.permissionDenied {
            TunerStatusBanner(
                icon: "mic.slash.fill",
                title: L10n.tr("没有麦克风权限"),
                message: L10n.tr("请在系统设置中允许 PTuner 使用麦克风，然后返回重试。"),
                actionTitle: L10n.tr("去设置"),
                action: { PlatformActions.openMicrophoneSettings() }
            )
        } else if let error = tuner.errorText {
            TunerStatusBanner(
                icon: "exclamationmark.triangle.fill",
                title: L10n.tr("音频输入不可用"),
                message: error,
                actionTitle: L10n.tr("重试"),
                action: { tuner.start() }
            )
        }
    }

    // MARK: - 额度用尽 / Pro 锁定

    private var lockedCard: some View {
        VStack(spacing: 14) {
            ProLockBadge(placement: .center, hostSize: .zero)

            Text(quota.chordExhaustion?.title ?? L10n.tr("今天的免费额度已用完"))
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text(quota.chordExhaustion?.message(for: .chordRecognition)
                 ?? L10n.tr("免费用户每天可享 30 秒和弦识别。升级 Pro，想弹多久识别多久。"))
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)

            PrimaryTunerButton(title: L10n.tr("解锁 Pro"), systemImage: "sparkles") {
                presentPaywall()
            }
        }
        .frame(maxWidth: .infinity)
        .tunerCard(padding: 22)
    }

    // MARK: - 识别结果

    private var chordPanel: some View {
        VStack(spacing: 14) {
            Text(L10n.tr("识别到和弦"))
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(chordMatch?.name ?? "—")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)

            Text(chordMatch?.compositionNames.joined(separator: " · ") ?? L10n.tr("弹奏和弦以开始识别"))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)

            Text(chordStatusText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(chordStatusColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(chordStatusColor.opacity(0.12))
                .clipShape(Capsule())

            if !chordRows.isEmpty {
                Divider().overlay(AppTheme.divider)

                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.tr("组成音"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.secondaryText)

                    ForEach(Array(chordRows.enumerated()), id: \.element.id) { index, row in
                        chordRowView(row, index: index)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity)
        .tunerCard(padding: 18)
    }

    private func chordRowView(_ row: PolyStringReading, index: Int) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(row.status.color.opacity(0.14))
                    .frame(width: 26, height: 26)
                Text("\(index + 1)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(row.status.color)
            }

            Text(row.noteName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .frame(minWidth: 44, alignment: .leading)

            Text(String(format: "%.2f Hz", row.frequency))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()

            Text(String(format: "%+.1f cents", row.cents))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(row.status.color)
        }
    }

    private var chordStatusText: String {
        guard isChordListening else { return L10n.tr("未开始监听") }
        if live.polyReadouts.isEmpty { return L10n.tr("等待声音") }
        if chordMatch != nil { return L10n.tr("识别成功") }
        if live.polyReadouts.count < 3 { return L10n.tr("识别中 · 需要更多组成音") }
        return L10n.tr("识别中")
    }

    private var chordStatusColor: Color {
        guard isChordListening else { return AppTheme.tertiaryText }
        if chordMatch != nil { return AppTheme.success }
        if live.polyReadouts.isEmpty { return AppTheme.tertiaryText }
        return AppTheme.warning
    }

    private var chordControlCard: some View {
        startStopButton
            .frame(maxWidth: .infinity)
            .tunerCard(padding: 16)
    }

    @ViewBuilder
    private var startStopButton: some View {
        if isChordListening, tuner.isStarting {
            PrimaryTunerButton(title: L10n.tr("正在启动…"), systemImage: "hourglass", role: .secondary) {}
        } else if isChordListening {
            PrimaryTunerButton(title: L10n.tr("停止监听"), systemImage: "stop.fill", role: .secondary) {
                stopChordListening()
            }
        } else {
            PrimaryTunerButton(title: L10n.tr("开始监听"), systemImage: "mic.fill") {
                startChordListening()
            }
        }
    }

    // MARK: - 行为

    /// 主动开始监听；多音通道只在用户点击后才占用。
    private func startChordListening() {
        quota.refreshNow()
        guard quota.chordExhaustion == nil else {
            quotaAlert = quota.chordExhaustion
            return
        }

        lastPolyAnalyzedSeconds = live.polyAnalyzedSeconds
        isChordListening = true

        if tuner.isRunning {
            syncChordDemand()
        } else {
            tuner.start()
        }
    }

    private func stopChordListening() {
        isChordListening = false
        tuner.setChordRecognitionActive(false)
    }

    /// 只有用户主动开始、停留在和弦页且额度可用时才占用多音通道。
    private func syncChordDemand() {
        let shouldActivate = isChordListening
            && router.selectedTab == .chord
            && !chordLocked
        tuner.setChordRecognitionActive(shouldActivate)
    }

    private func presentPaywall() {
        Task {
            await paywallManager.presentPaywall(
                featureID: "chord_recognition",
                marketingMessage: L10n.tr("升级 Pro，解锁实时和弦识别。")
            )
        }
    }
}
