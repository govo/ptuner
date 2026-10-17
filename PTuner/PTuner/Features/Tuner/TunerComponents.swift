import SwiftUI

// MARK: - 调音模式

enum TunerMode: String, CaseIterable, Identifiable {
    case single
    case multi
    case chord

    var id: String { rawValue }

    var title: String {
        switch self {
        case .single: return "单音"
        case .multi: return "多音"
        case .chord: return "和弦"
        }
    }

    /// 多音与和弦识别属于 Pro 功能。
    var requiresPro: Bool {
        self != .single
    }

    var featureID: String {
        switch self {
        case .single: return "single_pitch"
        case .multi: return "multi_pitch"
        case .chord: return "chord_recognition"
        }
    }
}

// MARK: - 状态颜色

extension TuningStatus {
    var color: Color {
        switch self {
        case .idle: return AppTheme.tertiaryText
        case .inTune: return AppTheme.success
        case .low, .high: return AppTheme.warning
        case .veryLow, .veryHigh: return AppTheme.danger
        }
    }

    var symbolName: String {
        switch self {
        case .idle: return "minus"
        case .inTune: return "checkmark"
        case .low, .veryLow: return "arrow.down"
        case .high, .veryHigh: return "arrow.up"
        }
    }
}

// MARK: - 卡片

extension View {
    func tunerCard(padding: CGFloat = 18, cornerRadius: CGFloat = 22) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(AppTheme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(AppTheme.cardBorder, lineWidth: 1)
            )
            .shadow(color: AppTheme.shadow.opacity(0.25), radius: 12, x: 0, y: 5)
    }
}

// MARK: - 乐器图标

struct InstrumentGlyph: View {
    let kind: InstrumentKind
    var tint: Color? = nil

    var body: some View {
        let color = tint ?? AppTheme.tint(for: kind)
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            let neckHeight = neckRatio * h
            let neckCenterY = neckCenterRatio * h

            ZStack {
                Capsule()
                    .fill(color.opacity(0.9))
                    .frame(width: w * 0.18, height: neckHeight)
                    .position(x: w * 0.5, y: neckCenterY)

                RoundedRectangle(cornerRadius: w * 0.05, style: .continuous)
                    .fill(color)
                    .frame(width: w * 0.30, height: h * 0.09)
                    .position(x: w * 0.5, y: h * 0.055)

                Circle()
                    .fill(color)
                    .frame(width: w * 0.56, height: w * 0.56)
                    .position(x: w * 0.5, y: h * 0.60)

                Circle()
                    .fill(color)
                    .frame(width: w * 0.74, height: w * 0.74)
                    .position(x: w * 0.5, y: h * 0.76)

                Circle()
                    .fill(AppTheme.surface)
                    .frame(width: w * 0.15, height: w * 0.15)
                    .position(x: w * 0.5, y: h * (kind == .ukulele ? 0.62 : 0.635))

                HStack(spacing: w * 0.06) {
                    ForEach(0..<3, id: \.self) { _ in
                        Capsule()
                            .fill(AppTheme.surface.opacity(0.85))
                            .frame(width: max(0.8, w * 0.02), height: h * 0.42)
                    }
                }
                .position(x: w * 0.5, y: h * 0.37)
            }
        }
        .aspectRatio(0.62, contentMode: .fit)
        .accessibilityHidden(true)
    }

    private var neckRatio: CGFloat {
        switch kind {
        case .bass: return 0.52
        case .ukulele: return 0.36
        default: return 0.46
        }
    }

    private var neckCenterRatio: CGFloat {
        switch kind {
        case .bass: return 0.31
        case .ukulele: return 0.27
        default: return 0.30
        }
    }
}

// MARK: - 音分条

struct CentsBar: View {
    let cents: Double
    let status: TuningStatus
    var height: CGFloat = 6

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let ratio = max(-1.0, min(1.0, cents / 50.0))
            let fillWidth = max(3, abs(ratio) * width / 2)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.gaugeTrack)
                    .frame(height: height)

                Capsule()
                    .fill(status.color)
                    .frame(width: fillWidth, height: height)
                    .offset(x: ratio >= 0 ? width / 2 : width / 2 - fillWidth)

                Rectangle()
                    .fill(AppTheme.secondaryText.opacity(0.45))
                    .frame(width: 1.5, height: height + 6)
                    .offset(x: width / 2 - 0.75)
            }
            .frame(maxHeight: .infinity)
        }
        .frame(height: height + 6)
    }
}

// MARK: - 电平波形

struct AudioLevelWaveform: View {
    let level: Float
    let isActive: Bool
    var barCount = 34

    @State private var samples: [CGFloat] = Array(repeating: 0.08, count: 34)

    var body: some View {
        HStack(alignment: .center, spacing: 2) {
            ForEach(Array(samples.enumerated()), id: \.offset) { index, value in
                Capsule()
                    .fill(isActive
                          ? AppTheme.accent.opacity(0.75)
                          : AppTheme.tertiaryText.opacity(0.35))
                    .frame(width: 2, height: barHeight(value: value, index: index))
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .onChange(of: level) { _, newValue in
            samples.removeFirst()
            samples.append(CGFloat(min(1, max(0.05, newValue * 16))))
        }
        .onAppear {
            if samples.count != barCount {
                samples = Array(repeating: 0.08, count: barCount)
            }
        }
        .accessibilityHidden(true)
    }

    private func barHeight(value: CGFloat, index: Int) -> CGFloat {
        let wave = 0.45 + 0.55 * abs(sin(Double(index) * 0.62))
        return max(3, value * 32 * wave)
    }
}

// MARK: - 输入状态条

/// 常驻输入状态：当前输入源、输入电平与正在输入的音。
/// 放在调音主页顶部，单音/多音/和弦模式始终可见。
struct TunerInputStatusBar: View {
    let deviceName: String?
    let level: Float
    let isRunning: Bool
    /// 例如 "A4 · 440.00 Hz" 或 "E2 · B3 · E4"。
    let noteText: String
    /// macOS 下拉选择输入设备。nil 表示当前没有绑定选择动作。
    var selectedDeviceUID: String? = nil
    var onSelectDevice: ((String?) -> Void)? = nil

    #if os(macOS)
    @ObservedObject private var monitor = AudioInputDeviceMonitor.shared
    #endif

    private var hasSignal: Bool {
        isRunning && level > 0.002
    }

    private var levelRatio: CGFloat {
        CGFloat(min(1, max(0, level * 16)))
    }

    private var deviceLabelText: String {
        deviceName ?? (isRunning ? "输入设备不可用" : "未开始监听")
    }

    private var deviceLabel: some View {
        Text(deviceLabelText)
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(AppTheme.secondaryText)
            .lineLimit(1)
    }

    #if os(macOS)
    /// 输入源下拉：直接在这里切换设备，和设置页共用同一条持久化链路。
    private var deviceMenu: some View {
        Menu {
            Button {
                onSelectDevice?(nil)
            } label: {
                if selectedDeviceUID == nil {
                    Label(systemDefaultMenuTitle, systemImage: "checkmark")
                } else {
                    Text(systemDefaultMenuTitle)
                }
            }

            if !monitor.devices.isEmpty {
                Divider()
            }

            ForEach(monitor.devices) { device in
                Button {
                    onSelectDevice?(device.id)
                } label: {
                    if selectedDeviceUID == device.id {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Text(deviceLabelText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineLimit(1)

                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(AppTheme.tertiaryText)
            }
            .contentShape(Rectangle())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .help("选择音频输入设备")
        .accessibilityLabel("输入设备：\(deviceLabelText)")
    }

    private var systemDefaultMenuTitle: String {
        if let uid = monitor.defaultDeviceUID,
           let device = monitor.devices.first(where: { $0.id == uid }) {
            return "系统默认 · \(device.name)"
        }
        return "系统默认"
    }
    #endif

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill((isRunning ? AppTheme.success : AppTheme.tertiaryText).opacity(0.13))

                Image(systemName: isRunning ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isRunning ? AppTheme.success : AppTheme.tertiaryText)
            }
            .frame(width: 34, height: 34)

            VStack(alignment: .leading, spacing: 3) {
                #if os(macOS)
                if onSelectDevice != nil {
                    deviceMenu
                } else {
                    deviceLabel
                }
                #else
                deviceLabel
                #endif

                Text(noteText)
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(hasSignal ? AppTheme.primaryText : AppTheme.tertiaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 5) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppTheme.gaugeTrack)

                        Capsule()
                            .fill(hasSignal ? AppTheme.success : AppTheme.tertiaryText.opacity(0.4))
                            .frame(width: max(3, geo.size.width * levelRatio))
                    }
                }
                .frame(width: 76, height: 6)

                Text(hasSignal ? "有输入" : (isRunning ? "无输入" : "已停止"))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(hasSignal ? AppTheme.success : AppTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(hasSignal ? AppTheme.success.opacity(0.25) : AppTheme.cardBorder, lineWidth: 1)
        )
        .animation(.easeOut(duration: 0.12), value: levelRatio)
    }
}

// MARK: - 模式切换

struct TunerModePicker: View {
    let mode: TunerMode
    let showsLocks: Bool
    let onSelect: (TunerMode) -> Void

    var body: some View {
        HStack(spacing: 4) {
            ForEach(TunerMode.allCases) { item in
                Button {
                    onSelect(item)
                } label: {
                    HStack(spacing: 4) {
                        Text(item.title)
                            .font(.system(size: 14, weight: .semibold))
                        if showsLocks && item.requiresPro {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 9, weight: .bold))
                        }
                    }
                    .foregroundStyle(item == mode ? AppTheme.onAccent : AppTheme.secondaryText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(item == mode ? AppTheme.accent : Color.clear)
                    )
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            Capsule()
                .fill(AppTheme.segmentBackground)
        )
    }
}

// MARK: - 状态横幅

struct TunerStatusBanner: View {
    let icon: String
    let title: String
    let message: String
    var actionTitle: String?
    var action: (@MainActor () -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.warning)
                .frame(width: 28, height: 28)
                .background(AppTheme.warning.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)
                Text(message)
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

            if let actionTitle, let action {
                Button(actionTitle) { action() }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(AppTheme.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentSoft)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
            }
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(AppTheme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.warning.opacity(0.25), lineWidth: 1)
        )
    }
}

// MARK: - 空状态

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(AppTheme.tertiaryText)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.primaryText)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(AppTheme.secondaryText)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - 主按钮

struct PrimaryTunerButton: View {
    let title: String
    let systemImage: String
    var role: Role = .primary
    let action: () -> Void

    enum Role {
        case primary
        case secondary
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .bold))
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(role == .primary ? AppTheme.onAccent : AppTheme.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(role == .primary ? AppTheme.accent : AppTheme.controlBackground)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
