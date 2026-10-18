import RevenueCatPaywallKit
import SwiftUI

/// 调音器主页：页面骨架固定，单音与多音只替换中间的调音表区域。
struct TunerHomeView: View {
    @EnvironmentObject private var tuner: TunerController
    @EnvironmentObject private var live: TunerRealtimeState
    @EnvironmentObject private var library: InstrumentLibrary
    @EnvironmentObject private var settings: TunerSettings
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var paywallManager: RevenueCatPaywallManager
    @ObservedObject private var proAccess = ProAccessController.shared
    @ObservedObject private var quota = FreeUsageQuota.shared

    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("ptuner.multiTuningEnabled") private var multiEnabled = false
    @StateObject private var verificationStore = PolyStringVerificationStore()
    @StateObject private var tonePlayer = TonePlayer()
    @State private var hasAutoStarted = false
    @State private var lastPolyAnalyzedSeconds: Double = 0
    @State private var quotaAlert: FreeUsageQuota.Limit?

    // MARK: - 派生数据

    private var preset: TuningPreset? {
        library.selectedPreset
    }

    private var reading: TuningReading? {
        TuningReading.make(rawMidi: live.liveMidi,
                           referencePitch: settings.referencePitch,
                           preset: preset)
    }

    /// 以选定乐器的全部目标弦为主体的整琴校验数据。
    private var resolvedSlots: [PolyStringVerificationStore.ResolvedSlot] {
        let fresh = PolyStringReadingBuilder.buildSlots(readouts: live.polyReadouts,
                                                        referencePitch: settings.referencePitch,
                                                        preset: preset)
        return verificationStore.resolve(fresh)
    }

    /// 半音阶调音没有目标弦，多音表退化为实时检测音列表。
    private var freePolyRows: [PolyStringReading] {
        PolyReadingBuilder.build(readouts: live.polyReadouts,
                                 referencePitch: settings.referencePitch,
                                 preset: nil)
    }

    private var proUnlocked: Bool {
        proAccess.isPro(paywallManager)
    }

    /// 免费用户的每日 / 每周额度用尽后，多音开关变成 Pro 锁。
    private var polyphonyLocked: Bool {
        !proUnlocked && quota.exhaustion != nil
    }

    /// 乐器模式跟随乐器弦数，半音阶模式使用用户在设置中选择的值。
    private var effectiveMaxPolyphony: Int {
        guard let preset else { return settings.maxPolyphony }
        return min(12, max(2, preset.stringCount))
    }

    /// 只拨响一根弦时，用 CREPE 的实时单音读数驱动这根弦的指针。
    /// 一旦多音通道同时识别到多个音，就交回多音读数，避免两路数据打架。
    private var liveStringCents: MultiStringTuningStrip.LiveCents? {
        guard multiEnabled, let match = liveStringMatch() else { return nil }

        if !live.polyReadouts.isEmpty {
            guard live.polyReadouts.count == 1,
                  resolvedSlots.contains(where: {
                      $0.slot.stringIndex == match.index && $0.slot.isDetected
                  }) else { return nil }
        }

        return MultiStringTuningStrip.LiveCents(stringIndex: match.index,
                                                cents: match.cents)
    }

    /// 把 CREPE 的实时音高落到最近的目标弦上。
    /// 使用和整琴校验一致的 1.5 半音门限，明显跑音的弦也能立刻显示偏差。
    private func liveStringMatch() -> (index: Int, cents: Double)? {
        guard let reading else { return nil }
        if let index = reading.matchedStringIndex {
            return (index, reading.cents)
        }
        guard let preset else { return nil }

        var best: (index: Int, diff: Double)?
        for (index, string) in preset.strings.enumerated() {
            let target = Double(string.midiNote) + string.centsOffset / 100.0
            let diff = reading.adjustedMidi - target
            guard abs(diff) <= PolyStringReadingBuilder.assignmentToleranceSemitones else { continue }
            if best == nil || abs(diff) < abs(best!.diff) {
                best = (index, diff)
            }
        }

        guard let best else { return nil }
        return (best.index, best.diff * 100.0)
    }

    // MARK: - Body

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(spacing: 16) {
                    header
                    statusBanners
                    contentLayout
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
            applyEffectivePolyphony()
            quota.refreshNow()
            lastPolyAnalyzedSeconds = live.polyAnalyzedSeconds
            if multiEnabled && polyphonyLocked {
                multiEnabled = false
            }
            tuner.setMultiStringTuningEnabled(multiEnabled)
            autoStartIfNeeded()

            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(500))
                verificationStore.purgeExpired()
            }
        }
        .onChange(of: multiEnabled) { _, enabled in
            if enabled {
                lastPolyAnalyzedSeconds = live.polyAnalyzedSeconds
                applyEffectivePolyphony()
            } else {
                verificationStore.reset()
            }
            tuner.setMultiStringTuningEnabled(enabled)
            AppDiagnostics.breadcrumb(.tuner, enabled ? "multi_on" : "multi_off")
        }
        .onChange(of: proUnlocked) { _, unlocked in
            // 降级为免费用户时，如果额度已经用尽，立即停止多音。
            if !unlocked, multiEnabled, quota.exhaustion != nil {
                multiEnabled = false
            }
        }
        .onChange(of: live.polyAnalyzedSeconds) { _, seconds in
            defer { lastPolyAnalyzedSeconds = seconds }
            guard multiEnabled,
                  tuner.isRunning,
                  tuner.polyphonicEnabled,
                  !proUnlocked else { return }

            let delta = seconds - lastPolyAnalyzedSeconds
            // 重置或异常跳变不计入额度。
            guard delta > 0, delta < 5 else { return }
            quota.recordPolyphonic(seconds: delta)
        }
        .onChange(of: quota.exhaustion) { _, limit in
            guard let limit else { return }
            if multiEnabled {
                multiEnabled = false
            }
            if !proUnlocked {
                quotaAlert = limit
            }
        }
        .onChange(of: tuner.polyphonyDemands) { _, demands in
            // 多音模型加载失败时控制器会清空需求，让开关同步回弹。
            if multiEnabled,
               !demands.contains(.multiStringTuning),
               !tuner.isPreparingPoly {
                multiEnabled = false
            }
        }
        .onChange(of: settings.maxPolyphony) { _, _ in
            applyEffectivePolyphony()
        }
        .onChange(of: library.selectedPresetID) { _, _ in
            verificationStore.reset()
            applyEffectivePolyphony()
        }
        .onChange(of: live.polyReadouts) { _, _ in
            ingestPolyReadouts()
        }
        .onChange(of: tuner.isRunning) { _, running in
            if !running {
                verificationStore.reset()
            }
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            quota.refreshNow()
            guard tuner.permissionDenied, !tuner.isRunning else { return }
            tuner.start()
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
                    presentMultiPaywall()
                }
            }

            Button(L10n.tr("以后再说"), role: .cancel) {
                quotaAlert = nil
            }
        } message: {
            Text(quotaAlert?.message ?? "")
        }
    }

    // MARK: - 固定骨架

    @ViewBuilder
    private var contentLayout: some View {
        #if os(macOS)
        HStack(alignment: .top, spacing: 18) {
            tuningArea
                .frame(maxWidth: .infinity, alignment: .top)

            VStack(spacing: 14) {
                instrumentCard
                multiToggleCard
            }
            .frame(width: 310)
        }
        #else
        VStack(spacing: 14) {
            tuningArea
            instrumentCard
            multiToggleCard
        }
        #endif
    }

    /// 唯一随单音/多音切换而变化的部分。
    @ViewBuilder
    private var tuningArea: some View {
        if multiEnabled {
            multiTuningPanel
        } else {
            singlePanel
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "tuningfork")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(AppTheme.gaugeBlue)
                .shadow(color: AppTheme.gaugeBlue.opacity(0.7), radius: 8)

            Text(L10n.tr("调音器"))
                .font(.system(size: 27, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 8)

            #if os(macOS)
            TunerHeaderInputStatus(deviceName: tuner.activeInputDeviceName,
                                   level: live.level,
                                   isRunning: tuner.isRunning,
                                   selectedDeviceUID: settings.preferredInputDeviceUID,
                                   onSelectDevice: selectInputDevice)
            #else
            TunerHeaderInputStatus(deviceName: tuner.activeInputDeviceName,
                                   level: live.level,
                                   isRunning: tuner.isRunning)
            #endif
        }
    }

    #if os(macOS)
    /// 在调音页直接切换输入设备，选择会持久化并与设置页保持一致。
    private func selectInputDevice(_ uid: String?) {
        guard uid != settings.preferredInputDeviceUID else { return }
        settings.preferredInputDeviceUID = uid
        settings.apply(to: tuner)
        applyEffectivePolyphony()
    }
    #endif

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

    // MARK: - 单音调音表

    private var singlePanel: some View {
        VStack(spacing: 8) {
            readoutArea
                .background(gaugeHalo)

            directionLine(status: reading?.status ?? .idle)

            if let preset {
                stringChips(preset: preset)
                    .padding(.top, 4)
            } else {
                Text(L10n.tr("半音阶调音 · 显示距离最近的标准音"))
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .padding(.top, 6)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.bottom, 4)
    }

    /// 指针表内部直接叠放音名、频率与音分胶囊，整体高度更紧凑。
    @ViewBuilder
    private var readoutArea: some View {
        switch settings.indicatorStyle {
        case .needle:
            ZStack(alignment: .bottom) {
                NeedleGaugeView(cents: reading?.cents,
                                status: reading?.status ?? .idle)

                noteReadout
                    .padding(.bottom, 2)
            }
        case .bar:
            VStack(spacing: 14) {
                HorizontalGaugeView(cents: reading?.cents,
                                    status: reading?.status ?? .idle)

                noteReadout
            }
            .padding(.top, 10)
        }
    }

    private var noteReadout: some View {
        VStack(spacing: 2) {
            Text(reading?.noteName ?? "—")
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .foregroundStyle(reading == nil
                                 ? AppTheme.tertiaryText.opacity(0.45)
                                 : AppTheme.primaryText)
                .monospacedDigit()
                .contentTransition(.numericText())
                .shadow(color: reading == nil ? .clear : Color.white.opacity(0.10),
                        radius: 16)

            Text(frequencyText(reading?.frequency))
                .font(.system(size: 14, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)

            statusPill(status: reading?.status ?? .idle)
                .padding(.top, 5)
        }
        .padding(.horizontal, 20)
    }

    /// 调音表背后的氛围光：跟随当前音准状态，让发光感不只是装饰。
    private var gaugeHalo: some View {
        let color = reading.map { $0.status.color } ?? AppTheme.accent

        return RadialGradient(colors: [color.opacity(reading == nil ? 0.03 : 0.14), .clear],
                              center: .center,
                              startRadius: 0,
                              endRadius: 230)
            .blur(radius: 24)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func stringChips(preset: TuningPreset) -> some View {
        // 12 弦以内保持一排；古筝 21 弦、坎侬琴 26 组弦等多弦乐器改用网格，
        // 否则每根弦会被压缩到无法点击的宽度。
        if preset.stringCount <= 12 {
            HStack(spacing: 4) {
                stringChipButtons(preset: preset)
            }
            .padding(.vertical, 4)
        } else {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 42, maximum: 68), spacing: 6)],
                      spacing: 8) {
                stringChipButtons(preset: preset)
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private func stringChipButtons(preset: TuningPreset) -> some View {
        ForEach(Array(preset.strings.enumerated()), id: \.offset) { index, string in
            let isActive = reading?.matchedStringIndex == index
            let status = isActive ? (reading?.status ?? .idle) : .idle

            Button {
                playReferenceTone(frequency: string.frequency(referenceA4: settings.referencePitch))
            } label: {
                VStack(spacing: 5) {
                    Text(string.displayName)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(isActive ? status.color : AppTheme.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    ZStack {
                        Circle()
                            .fill(isActive
                                  ? AnyShapeStyle(status.color.opacity(0.16))
                                  : AnyShapeStyle(Color.white.opacity(0.055)))

                        Circle()
                            .stroke(isActive ? status.color.opacity(0.6) : Color.white.opacity(0.09),
                                    lineWidth: 0.8)

                        if isActive {
                            Image(systemName: status.symbolName)
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(status.color)
                                .shadow(color: status.color.opacity(0.8), radius: 4)
                        } else {
                            Text("\(preset.stringNumber(at: index))")
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                    }
                    .frame(width: 32, height: 32)
                    .shadow(color: isActive ? status.color.opacity(0.35) : .clear, radius: 8)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(L10n.tr("播放 %@ 参考音", string.displayName))
            .animation(.easeOut(duration: 0.15), value: isActive)
        }
    }

    /// 点击弦位时播放该弦的目标音高（已计入音分偏移与 A4 参考音高）。
    private func playReferenceTone(frequency: Double) {
        tonePlayer.play(frequency: frequency, waveform: settings.referenceToneWaveform)
    }

    /// 参考图里的音准胶囊：显示音分读数，颜色与光晕跟随音准状态。
    private func statusPill(status: TuningStatus) -> some View {
        let isIdle = status == .idle
        let color = isIdle ? AppTheme.secondaryText : status.color
        let text = reading.map { centsText($0.cents) } ?? "—"

        return Text(text)
            .font(.system(size: 15, weight: .semibold, design: .rounded))
            .foregroundStyle(color)
            .monospacedDigit()
            .padding(.horizontal, 16)
            .padding(.vertical, 7)
            .background(
                Capsule()
                    .fill(isIdle ? Color.white.opacity(0.055) : color.opacity(0.14))
            )
            .overlay(
                Capsule()
                    .stroke(isIdle ? Color.white.opacity(0.08) : color.opacity(0.26),
                            lineWidth: 0.8)
            )
            .shadow(color: isIdle ? .clear : color.opacity(0.35), radius: 14)
            .animation(.easeOut(duration: 0.18), value: status)
    }

    /// 胶囊下方的方向提示：「— 稍低 —」。
    private func directionLine(status: TuningStatus) -> some View {
        HStack(spacing: 10) {
            dashLine

            Text(status.directionText)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(status == .idle ? AppTheme.tertiaryText : status.color.opacity(0.9))

            dashLine
        }
        .animation(.easeOut(duration: 0.18), value: status)
    }

    private var dashLine: some View {
        Rectangle()
            .fill(Color.white.opacity(0.14))
            .frame(width: 26, height: 1)
    }

    // MARK: - 多音调音表

    @ViewBuilder
    private var multiTuningPanel: some View {
        if preset != nil {
            MultiStringTuningStrip(resolved: resolvedSlots,
                                   centsPrecision: settings.centsPrecision,
                                   liveCents: liveStringCents,
                                   onPlayTone: playReferenceTone)
        } else {
            freeTuningPolyPanel
        }
    }

    /// 半音阶调音：没有目标弦，只展示当前检测到的音。
    private var freeTuningPolyPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(L10n.tr("实时检测音"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Spacer()

                if !live.polyReadouts.isEmpty {
                    Text(L10n.tr("%d 个音", live.polyReadouts.count))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(AppTheme.accent)
                }
            }

            if freePolyRows.isEmpty {
                VStack(spacing: 10) {
                    AudioLevelWaveform(level: live.level, isActive: tuner.isRunning)
                        .frame(height: 40)

                    Text(tuner.isRunning
                         ? L10n.tr("拨动琴弦后，这里会显示检测到的音")
                         : L10n.tr("点击开始后即可同时检测多个音"))
                        .font(.system(size: 13))
                        .foregroundStyle(AppTheme.secondaryText)
                        .frame(maxWidth: .infinity)
                        .multilineTextAlignment(.center)
                }
                .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(freePolyRows.enumerated()), id: \.element.id) { index, row in
                        freePolyRowView(row)
                        if index < freePolyRows.count - 1 {
                            Divider()
                                .overlay(AppTheme.divider)
                                .padding(.leading, 10)
                        }
                    }
                }
            }

            Text(L10n.tr("选择乐器后，可按该乐器的全部目标弦逐根校验"))
                .font(.system(size: 11))
                .foregroundStyle(AppTheme.tertiaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tunerCard(padding: 16)
    }

    private func freePolyRowView(_ row: PolyStringReading) -> some View {
        HStack(spacing: 12) {
            Text(row.noteName)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppTheme.primaryText)
                .frame(minWidth: 40, alignment: .leading)

            Text(frequencyText(row.frequency))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.secondaryText)

            Spacer(minLength: 4)

            Text(centsText(row.cents))
                .font(.system(size: 12, weight: .semibold, design: .monospaced))
                .foregroundStyle(row.status.color)

            CentsBar(cents: row.cents, status: row.status)
                .frame(width: 96)
        }
        .padding(.vertical, 9)
    }

    // MARK: - 乐器卡片

    @ViewBuilder
    private var instrumentCard: some View {
        VStack(spacing: 10) {
            TuningModeSegmentedControl(
                isFreeTuning: library.isFreeTuning,
                onSelectInstrument: selectInstrumentMode,
                onSelectChromatic: selectChromaticMode
            )

            if library.isFreeTuning {
                currentTuningRow
            } else {
                Button {
                    router.showInstruments()
                } label: {
                    currentTuningRow
                }
                .buttonStyle(.plain)
            }
        }
        .tunerCard(padding: 14)
    }

    /// 当前调音方式。乐器模式下可点击进入乐器列表；半音阶模式只作状态展示。
    private var currentTuningRow: some View {
        let tint = library.isFreeTuning
            ? AppTheme.accent
            : AppTheme.tint(for: (preset?.instrument ?? InstrumentCatalog.fallbackInstrument).family)

        return HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(colors: [tint.opacity(0.24), tint.opacity(0.06)],
                                       startPoint: .topLeading,
                                       endPoint: .bottomTrailing)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(tint.opacity(0.18), lineWidth: 0.8)
                    )

                if library.isFreeTuning {
                    Image(systemName: "waveform")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(tint)
                        .shadow(color: tint.opacity(0.6), radius: 8)
                } else {
                    InstrumentGlyph(instrument: preset?.instrument ?? InstrumentCatalog.fallbackInstrument)
                        .frame(width: 28, height: 46)
                }
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 6) {
                Text(library.isFreeTuning ? L10n.tr("半音阶调音") : (preset?.title ?? L10n.tr("吉他 · 标准调弦")))
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)

                Text(library.isFreeTuning ? L10n.tr("不用乐器，自动识别任意音高") : (preset?.notesSummary ?? ""))
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .tracking(library.isFreeTuning ? 0 : 3)
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if !library.isFreeTuning {
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
    }

    private func selectInstrumentMode() {
        guard library.isFreeTuning else { return }
        library.restoreLastInstrument()
        AppDiagnostics.breadcrumb(.tuner, "instrument_mode_selected")
    }

    private func selectChromaticMode() {
        guard !library.isFreeTuning else { return }
        library.selectFreeTuning()
        AppDiagnostics.breadcrumb(.tuner, "chromatic_selected")
    }

    // MARK: - 多音开关（固定位置）

    private var multiToggleCard: some View {
        VStack(spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(
                            LinearGradient(colors: [AppTheme.gaugeBlue.opacity(0.24),
                                                    AppTheme.gaugeBlue.opacity(0.06)],
                                           startPoint: .topLeading,
                                           endPoint: .bottomTrailing)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(AppTheme.gaugeBlue.opacity(0.18), lineWidth: 0.8)
                        )

                    Image(systemName: "waveform")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(AppTheme.gaugeBlue)
                        .shadow(color: AppTheme.gaugeBlue.opacity(0.6), radius: 6)
                }
                .frame(width: 40, height: 40)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 5) {
                        Text(L10n.tr("多音调音"))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(AppTheme.primaryText)

                        if !proUnlocked {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(AppTheme.tertiaryText)
                        }
                    }

                    Text(library.isFreeTuning
                         ? L10n.tr("同时识别多个音高，适合任意乐器")
                         : L10n.tr("同时检测多根弦，一次完成整琴校验"))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                }

                Spacer(minLength: 8)

                if polyphonyLocked {
                    proLockChip
                } else {
                    TunerSwitch(isOn: multiBinding)
                }
            }

            Divider()
                .overlay(AppTheme.divider)

            HStack(spacing: 6) {
                Text(library.isFreeTuning
                     ? L10n.tr("最大同时检测音数")
                     : L10n.tr("按乐器弦数自动检测"))
                    .font(.system(size: 13))
                    .foregroundStyle(AppTheme.secondaryText)

                Image(systemName: "info.circle")
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.tertiaryText)

                Spacer(minLength: 8)

                if library.isFreeTuning {
                    StepperValue(value: settings.maxPolyphony, range: 2...12) { value in
                        settings.setMaxPolyphony(value)
                    }
                    .opacity(multiEnabled ? 1 : 0.5)
                } else {
                    Text(L10n.tr("%d 个音", effectiveMaxPolyphony))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppTheme.primaryText.opacity(0.85))
                        .monospacedDigit()
                }
            }
            .opacity(multiEnabled ? 1 : 0.6)

            Divider()
                .overlay(AppTheme.divider)

            startStopButton
        }
        .tunerCard(padding: 16)
    }

    private var multiBinding: Binding<Bool> {
        Binding(
            get: { multiEnabled },
            set: { enabled in
                guard enabled else {
                    multiEnabled = false
                    return
                }
                guard !proUnlocked else {
                    multiEnabled = true
                    return
                }
                quota.refreshNow()
                if let limit = quota.exhaustion {
                    quotaAlert = limit
                    multiEnabled = false
                    return
                }
                multiEnabled = true
            }
        )
    }

    /// 额度用尽后替代开关的 Pro 锁。点击弹出升级提示，关闭则保持锁定。
    private var proLockChip: some View {
        Button {
            quota.refreshNow()
            if let limit = quota.exhaustion {
                quotaAlert = limit
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10, weight: .bold))

                Text("Pro")
                    .font(.system(size: 11, weight: .heavy, design: .rounded))
            }
            .foregroundStyle(AppTheme.warning)
            .padding(.horizontal, 11)
            .frame(height: 28)
            .background(
                Capsule().fill(AppTheme.warning.opacity(0.15))
            )
            .overlay(
                Capsule().stroke(AppTheme.warning.opacity(0.35), lineWidth: 0.8)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.tr("多音调音"))
    }

    // MARK: - 启停

    private var startStopButton: some View {
        Group {
            if tuner.isStarting {
                PrimaryTunerButton(title: L10n.tr("正在启动…"), systemImage: "hourglass", role: .secondary) {}
            } else if tuner.isRunning {
                PrimaryTunerButton(title: L10n.tr("停止监听"), systemImage: "stop.fill", role: .secondary) {
                    tuner.stop()
                }
            } else {
                PrimaryTunerButton(title: L10n.tr("开始检测"), systemImage: "mic.fill") {
                    tuner.start()
                }
            }
        }
    }

    // MARK: - 行为

    private func ingestPolyReadouts() {
        guard multiEnabled else { return }
        let slots = PolyStringReadingBuilder.buildSlots(readouts: live.polyReadouts,
                                                        referencePitch: settings.referencePitch,
                                                        preset: preset)
        verificationStore.ingest(slots)
    }

    /// 把当前模式实际需要的最大音数同步给调音器。
    private func applyEffectivePolyphony() {
        tuner.setMaxPolyphony(effectiveMaxPolyphony)
    }

    private func presentMultiPaywall() {
        Task {
            await paywallManager.presentPaywall(
                featureID: "multi_pitch",
                marketingMessage: L10n.tr("升级 Pro，解锁多音同时调音。")
            )
        }
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
        .background(
            Capsule()
                .fill(Color.black.opacity(0.32))
                .overlay(
                    Capsule()
                        .stroke(Color.white.opacity(0.07), lineWidth: 0.8)
                )
        )
    }

    private func stepButton(systemImage: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(enabled ? AppTheme.primaryText.opacity(0.9) : AppTheme.tertiaryText.opacity(0.5))
                .frame(width: 30, height: 30)
                .background(
                    Circle()
                        .fill(Color.white.opacity(enabled ? 0.08 : 0.03))
                )
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}
