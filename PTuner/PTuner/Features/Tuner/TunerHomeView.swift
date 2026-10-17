import RevenueCatPaywallKit
import SwiftUI

/// 调音器主页：单音、多音与和弦识别共用同一套视觉语言。
struct TunerHomeView: View {
    @EnvironmentObject private var tuner: TunerController
    @EnvironmentObject private var library: InstrumentLibrary
    @EnvironmentObject private var settings: TunerSettings
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager
    @ObservedObject private var proAccess = ProAccessController.shared

    @Environment(\.scenePhase) private var scenePhase
    @State private var mode: TunerMode = .single
    @State private var hasAutoStarted = false

    // MARK: - 派生数据

    private var preset: TuningPreset? {
        library.selectedPreset
    }

    private var reading: TuningReading? {
        TuningReading.make(rawMidi: tuner.liveMidi,
                           referencePitch: settings.referencePitch,
                           preset: preset)
    }

    private var polyRows: [PolyStringReading] {
        PolyReadingBuilder.build(readouts: tuner.polyReadouts,
                                 referencePitch: settings.referencePitch,
                                 preset: preset)
    }

    private var chordRows: [PolyStringReading] {
        polyRows.sorted { $0.midiPitch < $1.midiPitch }
    }

    private var chordMatch: ChordMatch? {
        ChordRecognizer.recognize(pitchClasses: tuner.polyReadouts.map(\.midiPitch))
    }

    private var proUnlocked: Bool {
        proAccess.isPro(paywallManager)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppTheme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header
                    inputStatusBar
                    modePicker
                    statusBanners
                    content
                }
                .padding(.horizontal, 18)
                .padding(.top, 8)
                .padding(.bottom, 28)
                .frame(maxWidth: 980)
                .frame(maxWidth: .infinity)
            }
        }
        .task {
            settings.apply(to: tuner)
            applyModeToTuner()
            autoStartIfNeeded()
        }
        .onChange(of: settings.stability) { _, _ in
            tuner.setDisplaySmoothing(settings.stability.smoothingFactor)
        }
        .onChange(of: settings.maxPolyphony) { _, value in
            tuner.setMaxPolyphony(value)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active, tuner.permissionDenied, !tuner.isRunning else { return }
            tuner.start()
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "tuningfork")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.accent)

            Text("调音器")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(AppTheme.primaryText)

            Spacer()

            Button {
                router.showSettings()
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.secondaryText)
                    .frame(width: 36, height: 36)
                    .background(AppTheme.surface)
                    .clipShape(Circle())
                    .overlay(Circle().stroke(AppTheme.cardBorder, lineWidth: 1))
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("设置")
        }
    }

    private var inputStatusBar: some View {
        #if os(macOS)
        TunerInputStatusBar(deviceName: tuner.activeInputDeviceName,
                            level: tuner.level,
                            isRunning: tuner.isRunning,
                            noteText: inputNoteText,
                            selectedDeviceUID: settings.preferredInputDeviceUID,
                            onSelectDevice: selectInputDevice)
        #else
        TunerInputStatusBar(deviceName: tuner.activeInputDeviceName,
                            level: tuner.level,
                            isRunning: tuner.isRunning,
                            noteText: inputNoteText)
        #endif
    }

    #if os(macOS)
    /// 在调音页直接切换输入设备，选择会持久化并与设置页保持一致。
    private func selectInputDevice(_ uid: String?) {
        guard uid != settings.preferredInputDeviceUID else { return }
        settings.preferredInputDeviceUID = uid
        settings.apply(to: tuner)
    }
    #endif

    /// 当前真正输入的音：单音显示音名与频率，多音/和弦显示正在检测的组成音。
    private var inputNoteText: String {
        guard tuner.isRunning else { return "未开始监听" }

        if mode == .single {
            guard let reading else { return "等待声音…" }
            return "\(reading.noteName) · \(frequencyText(reading.frequency))"
        }

        let pitches = tuner.polyReadouts
        guard !pitches.isEmpty else { return "等待声音…" }

        let names = pitches.prefix(4).map { NoteNames.name(midi: $0.midiPitch) }
        let summary = names.joined(separator: " · ")
        return pitches.count > 4 ? "\(summary) 等 \(pitches.count) 个音" : summary
    }

    private var modePicker: some View {
        TunerModePicker(mode: mode, showsLocks: !proUnlocked) { selected in
            select(selected)
        }
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

    // MARK: - 内容

    @ViewBuilder
    private var content: some View {
        #if os(macOS)
        if mode == .single {
            singleLayout
        } else {
            wideLayout(main: modePanel, side: sidePanel)
        }
        #else
        switch mode {
        case .single:
            VStack(spacing: 14) {
                singlePanel
                instrumentCard
                multiToggleCard
            }
        case .multi:
            VStack(spacing: 14) {
                polyPanel
                instrumentCard
                multiControlCard
            }
        case .chord:
            VStack(spacing: 14) {
                chordPanel
                instrumentCard
                chordControlCard
            }
        }
        #endif
    }

    private var modePanel: some View {
        Group {
            if mode == .multi {
                polyPanel
            } else {
                chordPanel
            }
        }
    }

    private var sidePanel: some View {
        VStack(spacing: 14) {
            instrumentCard
            if mode == .multi {
                multiControlCard
            } else {
                chordControlCard
            }
        }
    }

    private var singleLayout: some View {
        VStack(spacing: 14) {
            singlePanel
            instrumentCard
            multiToggleCard
        }
        .frame(maxWidth: 640)
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func wideLayout<Main: View, Side: View>(main: Main, side: Side) -> some View {
        HStack(alignment: .top, spacing: 18) {
            main
                .frame(maxWidth: .infinity)
            side
                .frame(width: 310)
        }
    }

    // MARK: - 单音

    private var singlePanel: some View {
        VStack(spacing: 14) {
            gauge

            VStack(spacing: 2) {
                Text(reading?.noteName ?? "—")
                    .font(.system(size: 58, weight: .heavy, design: .rounded))
                    .foregroundStyle(AppTheme.primaryText)
                    .monospacedDigit()
                    .contentTransition(.numericText())

                HStack(spacing: 16) {
                    Text(frequencyText(reading?.frequency))
                        .font(.system(size: 15, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)

                    if let reading {
                        Text(centsText(reading.cents))
                            .font(.system(size: 15, weight: .semibold, design: .monospaced))
                            .foregroundStyle(reading.status.color)
                    }
                }
            }

            statusPill(status: reading?.status ?? .idle,
                       activeText: reading?.status.directionText)

            if let preset {
                stringChips(preset: preset)
            } else {
                Text("自由调音 · 显示距离最近的标准音")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.tertiaryText)
            }

            startStopButton(compact: true)
        }
        .frame(maxWidth: .infinity)
        .tunerCard(padding: 18)
    }

    private var gauge: some View {
        Group {
            switch settings.indicatorStyle {
            case .needle:
                NeedleGaugeView(cents: reading?.cents, status: reading?.status ?? .idle)
            case .bar:
                HorizontalGaugeView(cents: reading?.cents, status: reading?.status ?? .idle)
            }
        }
    }

    private func stringChips(preset: TuningPreset) -> some View {
        HStack(spacing: 4) {
            ForEach(Array(preset.strings.enumerated()), id: \.offset) { index, string in
                let isActive = reading?.matchedStringIndex == index
                let status = isActive ? (reading?.status ?? .idle) : .idle

                VStack(spacing: 5) {
                    Text(string.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isActive ? AppTheme.accent : AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    ZStack {
                        Circle()
                            .fill(isActive ? status.color.opacity(0.14) : AppTheme.controlBackground)

                        Circle()
                            .stroke(isActive ? status.color.opacity(0.7) : AppTheme.cardBorder,
                                    lineWidth: 1)

                        if isActive {
                            Image(systemName: status.symbolName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(status.color)
                        } else {
                            Text("\(preset.stringNumber(at: index))")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                    }
                    .frame(width: 30, height: 30)
                }
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: 0.15), value: isActive)
            }
        }
        .padding(.vertical, 4)
    }

    private func statusPill(status: TuningStatus, activeText: String?) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 6, height: 6)

            Text(activeText ?? status.directionText)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(status == .idle ? AppTheme.secondaryText : status.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(status == .idle ? AppTheme.controlBackground : status.color.opacity(0.12))
        )
    }

    // MARK: - 多音

    private var polyPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("实时音高")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                if tuner.isPreparingPoly {
                    Text("准备多音模型…")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                } else if !tuner.polyReadouts.isEmpty {
                    Text("\(tuner.polyReadouts.count) 个音")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            if polyRows.isEmpty {
                VStack(spacing: 10) {
                    AudioLevelWaveform(level: tuner.level, isActive: tuner.isRunning)
                        .frame(height: 40)

                    Text(tuner.isRunning ? "拨动琴弦后，这里会显示每个音的偏差" : "点击开始后即可同时检测多个音")
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 22)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(polyRows.enumerated()), id: \.element.id) { index, row in
                        polyRowView(row)
                        if index < polyRows.count - 1 {
                            Divider()
                                .overlay(AppTheme.divider)
                                .padding(.leading, 44)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tunerCard(padding: 16)
    }

    private func polyRowView(_ row: PolyStringReading) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(row.status.color.opacity(row.isMatched ? 0.7 : 0.3), lineWidth: 2)

                if let number = row.stringNumber {
                    Text("\(number)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(row.status.color)
                } else {
                    Circle()
                        .fill(row.status.color.opacity(0.7))
                        .frame(width: 8, height: 8)
                }
            }
            .frame(width: 30, height: 30)

            VStack(spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.noteName)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText)
                        .frame(minWidth: 40, alignment: .leading)

                    Text(frequencyText(row.frequency))
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)

                    Spacer(minLength: 4)

                    Text(centsText(row.cents))
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(row.status.color)
                }

                CentsBar(cents: row.cents, status: row.status)
            }
        }
        .padding(.vertical, 9)
    }

    private var multiControlCard: some View {
        VStack(spacing: 14) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("最大检测音数")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("最多同时显示 \(settings.maxPolyphony) 个音")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer()

                StepperValue(value: settings.maxPolyphony, range: 2...12) { value in
                    settings.setMaxPolyphony(value)
                    tuner.setMaxPolyphony(value)
                }
            }

            Divider().overlay(AppTheme.divider)

            VStack(spacing: 8) {
                AudioLevelWaveform(level: tuner.level, isActive: tuner.isRunning)
                Text(detectingText)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
            }

            startStopButton(compact: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tunerCard(padding: 16)
    }

    private var detectingText: String {
        guard tuner.isRunning else { return "未开始检测" }
        if tuner.isPreparingPoly { return "正在准备多音模型…" }
        let count = min(tuner.polyReadouts.count, settings.maxPolyphony)
        return count == 0 ? "等待演奏…" : "\(count) 个音同时检测中…"
    }

    // MARK: - 和弦

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

            Text(frequencyText(row.frequency))
                .font(.system(size: 12, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer()

            Text(centsText(row.cents))
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

            startStopButton(compact: false)

            PrimaryTunerButton(title: "切换到调音模式",
                               systemImage: "tuningfork",
                               role: .secondary) {
                select(.single)
            }
        }
        .frame(maxWidth: .infinity)
        .tunerCard(padding: 16)
    }

    // MARK: - 乐器卡片

    @ViewBuilder
    private var instrumentCard: some View {
        Button {
            router.showInstruments()
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.tint(for: preset?.kind ?? .other).opacity(0.12))

                    InstrumentGlyph(kind: preset?.kind ?? .other)
                        .frame(width: 22, height: 36)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 4) {
                    Text(preset?.title ?? "自由调音")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)

                    Text(preset?.notesSummary ?? "不限制乐器和调弦方式")
                        .font(.system(size: 12, weight: .medium, design: .monospaced))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .tunerCard(padding: 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - 多音开关（单音模式）

    private var multiToggleCard: some View {
        VStack(spacing: 12) {
            Toggle(isOn: Binding(
                get: { mode == .multi },
                set: { isOn in
                    if isOn {
                        select(.multi)
                    } else {
                        select(.single)
                    }
                }
            )) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("多音调音")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(AppTheme.primaryText)
                    Text("同时检测多根弦，一次完成校音")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                }
            }
            .tint(AppTheme.accent)

            HStack {
                Text("一次最多检测 \(settings.maxPolyphony) 个音")
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)

                Spacer()

                StepperValue(value: settings.maxPolyphony, range: 2...12) { value in
                    settings.setMaxPolyphony(value)
                    tuner.setMaxPolyphony(value)
                }
            }
        }
        .tunerCard(padding: 16)
    }

    // MARK: - 按钮

    private func startStopButton(compact: Bool) -> some View {
        Group {
            if tuner.isStarting {
                PrimaryTunerButton(title: "正在启动…", systemImage: "hourglass", role: .secondary) {}
            } else if tuner.isRunning {
                PrimaryTunerButton(title: "停止监听", systemImage: "stop.fill", role: .secondary) {
                    tuner.stop()
                }
            } else {
                PrimaryTunerButton(title: compact ? "开始调音" : "开始检测", systemImage: "mic.fill") {
                    tuner.start()
                }
            }
        }
    }

    // MARK: - 行为

    private func select(_ newMode: TunerMode) {
        if newMode.requiresPro && !proUnlocked {
            Task {
                await paywallManager.presentPaywall(
                    featureID: newMode.featureID,
                    marketingMessage: newMode == .multi
                        ? "升级 Pro，解锁多音同时调音。"
                        : "升级 Pro，解锁实时和弦识别。"
                )
            }
            return
        }

        guard newMode != mode else { return }
        mode = newMode
        AppDiagnostics.breadcrumb(.tuner, "mode_\(newMode.rawValue)")
        applyModeToTuner()
    }

    private func applyModeToTuner() {
        tuner.setPolyphonicEnabled(mode != .single)
    }

    private func autoStartIfNeeded() {
        guard !hasAutoStarted else { return }
        hasAutoStarted = true
        guard !tuner.isRunning, !tuner.isStarting else { return }
        tuner.start()
    }

    // MARK: - 文案

    private func frequencyText(_ frequency: Double?) -> String {
        guard let frequency, frequency > 0 else { return "— Hz" }
        return String(format: "%.2f Hz", frequency)
    }

    private func centsText(_ cents: Double) -> String {
        "\(settings.centsPrecision.format(cents)) cents"
    }
}

// MARK: - 数值步进器

struct StepperValue: View {
    let value: Int
    let range: ClosedRange<Int>
    let onChange: (Int) -> Void

    var body: some View {
        HStack(spacing: 0) {
            stepButton(systemImage: "minus", enabled: value > range.lowerBound) {
                onChange(value - 1)
            }

            Text("\(value)")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .monospacedDigit()
                .frame(width: 42)

            stepButton(systemImage: "plus", enabled: value < range.upperBound) {
                onChange(value + 1)
            }
        }
        .padding(3)
        .background(AppTheme.controlBackground)
        .clipShape(Capsule())
    }

    private func stepButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(enabled ? AppTheme.primaryText : AppTheme.tertiaryText)
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
