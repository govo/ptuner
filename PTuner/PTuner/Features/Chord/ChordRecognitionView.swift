import RevenueCatPaywallKit
import SwiftUI

/// 和弦识别是独立功能：只依赖多音检测结果，不读取当前乐器或调弦配置。
struct ChordRecognitionView: View {
    @EnvironmentObject private var tuner: TunerController
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager
    @ObservedObject private var proAccess = ProAccessController.shared

    private var proUnlocked: Bool {
        proAccess.isPro(paywallManager)
    }

    private var chordRows: [PolyStringReading] {
        PolyReadingBuilder.build(readouts: tuner.polyReadouts,
                                 referencePitch: 440,
                                 preset: nil)
            .sorted { $0.midiPitch < $1.midiPitch }
    }

    private var chordMatch: ChordMatch? {
        ChordRecognizer.recognize(pitchClasses: tuner.polyReadouts.map(\.midiPitch))
    }

    private var inputNoteText: String {
        guard tuner.isRunning else { return "未开始监听" }
        let pitches = tuner.polyReadouts
        guard !pitches.isEmpty else { return "等待声音…" }

        let names = pitches.prefix(4).map { NoteNames.name(midi: $0.midiPitch) }
        let summary = names.joined(separator: " · ")
        return pitches.count > 4 ? "\(summary) 等 \(pitches.count) 个音" : summary
    }

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header
                    TunerInputStatusBar(deviceName: tuner.activeInputDeviceName,
                                        level: tuner.level,
                                        isRunning: tuner.isRunning,
                                        noteText: inputNoteText)
                    statusBanners

                    if proUnlocked {
                        contentLayout
                    } else {
                        proLockedCard
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
            syncChordDemand()
        }
        .onDisappear {
            tuner.setChordRecognitionActive(false)
        }
        .onChange(of: proUnlocked) { _, _ in
            syncChordDemand()
        }
        .onChange(of: router.selectedTab) { _, tab in
            if tab != .chord {
                tuner.setChordRecognitionActive(false)
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "music.note.list")
                .font(.system(size: 21, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            Text("和弦识别")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()
        }
    }

    @ViewBuilder
    private var contentLayout: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: 18) {
            chordPanel
                .frame(maxWidth: .infinity)
            chordControlCard
                .frame(width: 310)
        }
        #else
        VStack(spacing: 14) {
            chordPanel
            chordControlCard
        }
        #endif
    }

    @ViewBuilder
    private var statusBanners: some View {
        if tuner.permissionDenied {
            TunerStatusBanner(
                icon: "mic.slash.fill",
                title: "没有麦克风权限",
                message: "请在系统设置中允许 PTuner 使用麦克风，然后返回重试。",
                actionTitle: "去设置",
                action: { PlatformActions.openMicrophoneSettings() }
            )
        } else if let error = tuner.errorText {
            TunerStatusBanner(
                icon: "exclamationmark.triangle.fill",
                title: "音频输入不可用",
                message: error,
                actionTitle: "重试",
                action: { tuner.start() }
            )
        }
    }

    // MARK: - Pro 锁定

    private var proLockedCard: some View {
        VStack(spacing: 14) {
            Image(systemName: "music.note.list")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            Text("和弦识别是 Pro 功能")
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Text("升级后可以实时识别当前演奏的和弦名称与组成音，不受乐器选择影响。")
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)

            PrimaryTunerButton(title: "解锁 Pro", systemImage: "sparkles") {
                presentPaywall()
            }
        }
        .frame(maxWidth: .infinity)
        .tunerCard(padding: 22)
    }

    // MARK: - 识别结果

    private var chordPanel: some View {
        VStack(spacing: 14) {
            Text("识别到和弦")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(AppTheme.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(chordMatch?.name ?? "—")
                .font(.system(size: 46, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .contentTransition(.numericText())
                .frame(maxWidth: .infinity)

            Text(chordMatch?.compositionNames.joined(separator: " · ") ?? "弹奏和弦以开始识别")
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
                    Text("组成音")
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
        guard tuner.isRunning else { return "未开始检测" }
        if tuner.polyReadouts.isEmpty { return "等待声音" }
        if chordMatch != nil { return "识别成功" }
        if tuner.polyReadouts.count < 3 { return "识别中 · 需要更多组成音" }
        return "识别中"
    }

    private var chordStatusColor: Color {
        if chordMatch != nil { return AppTheme.success }
        if tuner.polyReadouts.isEmpty { return AppTheme.tertiaryText }
        return AppTheme.warning
    }

    private var chordControlCard: some View {
        VStack(spacing: 14) {
            AudioLevelWaveform(level: tuner.level, isActive: tuner.isRunning)

            Text(detectingText)
                .font(.system(size: 12))
                .foregroundStyle(AppTheme.secondaryText)

            startStopButton
        }
        .frame(maxWidth: .infinity)
        .tunerCard(padding: 16)
    }

    private var detectingText: String {
        guard tuner.isRunning else { return "未开始检测" }
        if tuner.isPreparingPoly { return "正在准备多音模型…" }
        let count = tuner.polyReadouts.count
        return count == 0 ? "等待演奏…" : "\(count) 个音同时检测中…"
    }

    @ViewBuilder
    private var startStopButton: some View {
        if tuner.isStarting {
            PrimaryTunerButton(title: "正在启动…", systemImage: "hourglass", role: .secondary) {}
        } else if tuner.isRunning {
            PrimaryTunerButton(title: "停止监听", systemImage: "stop.fill", role: .secondary) {
                tuner.stop()
            }
        } else {
            PrimaryTunerButton(title: "开始检测", systemImage: "mic.fill") {
                tuner.start()
            }
        }
    }

    // MARK: - 行为

    private func syncChordDemand() {
        tuner.setChordRecognitionActive(proUnlocked)
    }

    private func presentPaywall() {
        Task {
            await paywallManager.presentPaywall(
                featureID: "chord_recognition",
                marketingMessage: "升级 Pro，解锁实时和弦识别。"
            )
        }
    }
}
