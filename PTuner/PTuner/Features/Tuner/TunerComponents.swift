import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

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
    /// 全 App 统一的毛玻璃卡片：材质模糊 + 低透白色渐变 + 受光描边。
    func tunerCard(padding: CGFloat = 18, cornerRadius: CGFloat = 22) -> some View {
        self
            .padding(padding)
            .background(GlassCardBackground(cornerRadius: cornerRadius))
            .shadow(color: Color.black.opacity(0.38), radius: 22, x: 0, y: 12)
    }
}

// MARK: - 乐器图标

struct InstrumentGlyph: View {
    let style: InstrumentGlyphStyle
    /// Assets 图片名。图片存在时优先显示图片，否则回退到共享矢量轮廓。
    var imageName: String? = nil
    var tint: Color? = nil

    init(instrument: InstrumentDefinition, tint: Color? = nil) {
        self.style = instrument.glyph
        self.imageName = instrument.imageName
        self.tint = tint ?? AppTheme.tint(for: instrument)
    }

    init(style: InstrumentGlyphStyle, imageName: String? = nil, tint: Color? = nil) {
        self.style = style
        self.imageName = imageName
        self.tint = tint
    }

    var body: some View {
        let color = tint ?? AppTheme.accent

        Group {
            if let imageName, Self.hasAsset(named: imageName) {
                Image(imageName)
                    .resizable()
                    .scaledToFit()
            } else {
                GeometryReader { geo in
                    switch style {
                    case .guitar:
                        guitarGlyph(color: color, size: geo.size)
                    case .lute:
                        luteGlyph(color: color, size: geo.size)
                    case .bowed:
                        bowedGlyph(color: color, size: geo.size)
                    case .zither:
                        zitherGlyph(color: color, size: geo.size)
                    case .harp:
                        harpGlyph(color: color, size: geo.size)
                    }
                }
                .aspectRatio(0.62, contentMode: .fit)
            }
        }
        .accessibilityHidden(true)
    }

    private static func hasAsset(named name: String) -> Bool {
        #if os(macOS)
        return NSImage(named: name) != nil
        #else
        return UIImage(named: name) != nil
        #endif
    }

    // MARK: - 拨弦（吉他、贝斯、尤克里里）

    private func guitarGlyph(color: Color, size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let neckHeight = neckRatio * h
        let neckCenterY = neckCenterRatio * h

        return ZStack {
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
                .position(x: w * 0.5, y: h * 0.635)

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

    // MARK: - 短颈弹拨（曼陀林、琵琶、乌德琴等）

    private func luteGlyph(color: Color, size: CGSize) -> some View {
        let w = size.width
        let h = size.height

        return ZStack {
            Capsule()
                .fill(color.opacity(0.9))
                .frame(width: w * 0.16, height: h * 0.42)
                .position(x: w * 0.5, y: h * 0.26)

            RoundedRectangle(cornerRadius: w * 0.04, style: .continuous)
                .fill(color)
                .frame(width: w * 0.28, height: h * 0.08)
                .position(x: w * 0.5, y: h * 0.045)

            Ellipse()
                .fill(color)
                .frame(width: w * 0.78, height: h * 0.52)
                .position(x: w * 0.5, y: h * 0.70)

            Circle()
                .fill(AppTheme.surface)
                .frame(width: w * 0.17, height: w * 0.17)
                .position(x: w * 0.5, y: h * 0.68)

            HStack(spacing: w * 0.07) {
                ForEach(0..<3, id: \.self) { _ in
                    Capsule()
                        .fill(AppTheme.surface.opacity(0.85))
                        .frame(width: max(0.8, w * 0.018), height: h * 0.36)
                }
            }
            .position(x: w * 0.5, y: h * 0.36)
        }
    }

    // MARK: - 弓弦（小提琴、二胡、萨兰吉等）

    private func bowedGlyph(color: Color, size: CGSize) -> some View {
        let w = size.width
        let h = size.height

        return ZStack {
            Capsule()
                .fill(color)
                .frame(width: w * 0.13, height: h * 0.50)
                .position(x: w * 0.47, y: h * 0.30)

            RoundedRectangle(cornerRadius: w * 0.04, style: .continuous)
                .fill(color)
                .frame(width: w * 0.24, height: h * 0.07)
                .position(x: w * 0.47, y: h * 0.035)

            Ellipse()
                .fill(color)
                .frame(width: w * 0.46, height: h * 0.24)
                .position(x: w * 0.47, y: h * 0.62)

            Ellipse()
                .fill(color)
                .frame(width: w * 0.62, height: h * 0.30)
                .position(x: w * 0.47, y: h * 0.79)

            Capsule()
                .fill(color.opacity(0.55))
                .frame(width: max(1, w * 0.05), height: h * 0.78)
                .rotationEffect(.degrees(24))
                .position(x: w * 0.76, y: h * 0.46)
        }
    }

    // MARK: - 筝类（古筝、古琴、日本筝、扬琴等）

    private func zitherGlyph(color: Color, size: CGSize) -> some View {
        let w = size.width
        let h = size.height
        let inset = w * 0.16

        return ZStack {
            Path { path in
                path.move(to: CGPoint(x: inset, y: h * 0.18))
                path.addLine(to: CGPoint(x: w - inset * 0.5, y: h * 0.08))
                path.addLine(to: CGPoint(x: w - inset * 0.5, y: h * 0.88))
                path.addLine(to: CGPoint(x: inset, y: h * 0.96))
                path.closeSubpath()
            }
            .fill(color.opacity(0.92))

            HStack(spacing: w * 0.035) {
                ForEach(0..<6, id: \.self) { _ in
                    Capsule()
                        .fill(AppTheme.surface.opacity(0.8))
                        .frame(width: max(0.7, w * 0.014), height: h * 0.62)
                }
            }
            .rotationEffect(.degrees(-4))
            .position(x: w * 0.5, y: h * 0.54)
        }
    }

    // MARK: - 竖琴类（科拉琴、恩戈尼琴）

    private func harpGlyph(color: Color, size: CGSize) -> some View {
        let w = size.width
        let h = size.height

        return ZStack {
            Capsule()
                .fill(color)
                .frame(width: w * 0.12, height: h * 0.90)
                .position(x: w * 0.24, y: h * 0.52)

            Capsule()
                .fill(color)
                .frame(width: max(1, w * 0.07), height: h * 0.78)
                .rotationEffect(.degrees(-24))
                .position(x: w * 0.56, y: h * 0.48)

            RoundedRectangle(cornerRadius: w * 0.05, style: .continuous)
                .fill(color)
                .frame(width: w * 0.62, height: h * 0.09)
                .rotationEffect(.degrees(-10))
                .position(x: w * 0.52, y: h * 0.08)

            HStack(spacing: w * 0.05) {
                ForEach(0..<5, id: \.self) { _ in
                    Capsule()
                        .fill(AppTheme.surface.opacity(0.8))
                        .frame(width: max(0.7, w * 0.012), height: h * 0.66)
                }
            }
            .rotationEffect(.degrees(-6))
            .position(x: w * 0.48, y: h * 0.50)
        }
    }

    private var neckRatio: CGFloat { 0.46 }

    private var neckCenterRatio: CGFloat { 0.30 }
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
                    .fill(Color.white.opacity(0.07))
                    .frame(height: height)

                Capsule()
                    .fill(status.color)
                    .frame(width: fillWidth, height: height)
                    .offset(x: ratio >= 0 ? width / 2 : width / 2 - fillWidth)
                    .shadow(color: status.color.opacity(0.55), radius: 4)

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
                          ? AppTheme.gaugeBlue.opacity(0.9)
                          : AppTheme.tertiaryText.opacity(0.3))
                    .frame(width: 2, height: barHeight(value: value, index: index))
                    .shadow(color: isActive ? AppTheme.gaugeBlue.opacity(0.5) : .clear,
                            radius: 2)
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

    /// 截图演示：真实麦克风没有启动，但界面需要呈现稳定的运行中状态。
    private var effectiveDeviceName: String? {
        #if DEBUG
        if ScreenshotDemo.isActive { return ScreenshotDemo.inputDeviceName }
        #endif
        return deviceName
    }

    private var effectiveLevel: Float {
        #if DEBUG
        if ScreenshotDemo.isActive { return ScreenshotDemo.inputLevel }
        #endif
        return level
    }

    private var effectiveIsRunning: Bool {
        #if DEBUG
        if ScreenshotDemo.isActive { return true }
        #endif
        return isRunning
    }

    private var hasSignal: Bool {
        effectiveIsRunning && effectiveLevel > 0.002
    }

    private var levelRatio: CGFloat {
        CGFloat(min(1, max(0, effectiveLevel * 16)))
    }

    private var deviceLabelText: String {
        effectiveDeviceName ?? (effectiveIsRunning ? L10n.tr("输入设备不可用") : L10n.tr("未开始监听"))
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
        .help(L10n.tr("选择音频输入设备"))
        .accessibilityLabel(L10n.tr("输入设备：%@", deviceLabelText))
    }

    private var systemDefaultMenuTitle: String {
        if let uid = monitor.defaultDeviceUID,
           let device = monitor.devices.first(where: { $0.id == uid }) {
            return L10n.tr("系统默认 · %@", device.name)
        }
        return L10n.tr("系统默认")
    }
    #endif

    var body: some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill((effectiveIsRunning ? AppTheme.success : AppTheme.tertiaryText).opacity(0.13))

                Image(systemName: effectiveIsRunning ? "mic.fill" : "mic.slash.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(effectiveIsRunning ? AppTheme.success : AppTheme.tertiaryText)
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

                Text(hasSignal ? L10n.tr("有输入") : (effectiveIsRunning ? L10n.tr("无输入") : L10n.tr("已停止")))
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(hasSignal ? AppTheme.success : AppTheme.tertiaryText)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(GlassCardBackground(cornerRadius: 15))
        .overlay(
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .stroke(hasSignal ? AppTheme.success.opacity(0.22) : Color.white.opacity(0.08),
                        lineWidth: 0.8)
        )
        .animation(.easeOut(duration: 0.12), value: levelRatio)
    }
}

// MARK: - 头部输入状态

/// 调音页右上角的紧凑输入状态：输入源与输入电平。
/// 取代原来独占一行的输入状态条，节省一整条 UI 的高度。
struct TunerHeaderInputStatus: View {
    let deviceName: String?
    let level: Float
    let isRunning: Bool
    /// macOS 下拉选择输入设备。nil 表示当前没有绑定选择动作。
    var selectedDeviceUID: String? = nil
    var onSelectDevice: ((String?) -> Void)? = nil

    #if os(macOS)
    @ObservedObject private var monitor = AudioInputDeviceMonitor.shared
    @State private var showsDevicePicker = false
    @State private var isHovering = false
    #endif

    /// 截图演示：真实麦克风没有启动，但界面需要呈现稳定的运行中状态。
    private var effectiveDeviceName: String? {
        #if DEBUG
        if ScreenshotDemo.isActive { return ScreenshotDemo.inputDeviceName }
        #endif
        return deviceName
    }

    private var effectiveLevel: Float {
        #if DEBUG
        if ScreenshotDemo.isActive { return ScreenshotDemo.inputLevel }
        #endif
        return level
    }

    private var effectiveIsRunning: Bool {
        #if DEBUG
        if ScreenshotDemo.isActive { return true }
        #endif
        return isRunning
    }

    private var hasSignal: Bool {
        effectiveIsRunning && effectiveLevel > 0.002
    }

    private var levelRatio: CGFloat {
        CGFloat(min(1, max(0, effectiveLevel * 16)))
    }

    private var deviceLabelText: String {
        effectiveDeviceName ?? (effectiveIsRunning ? L10n.tr("输入设备不可用") : L10n.tr("未开始监听"))
    }

    private var isHighlighted: Bool {
        #if os(macOS)
        isHovering
        #else
        false
        #endif
    }

    var body: some View {
        #if os(macOS)
        if let onSelectDevice {
            // 不用 Menu 作为外层：macOS 的 Menu 会丢弃自定义 label 的
            // 背景、电平条与指示器，导致它与 iOS 外观不一致。
            Button {
                showsDevicePicker = true
            } label: {
                content(showsChevron: true)
            }
            .buttonStyle(.plain)
            .onHover { isHovering = $0 }
            .help(L10n.tr("选择音频输入设备"))
            .accessibilityLabel(L10n.tr("输入设备：%@", deviceLabelText))
            .popover(isPresented: $showsDevicePicker,
                     attachmentAnchor: .rect(.bounds),
                     arrowEdge: .top) {
                devicePicker(onSelect: onSelectDevice)
            }
        } else {
            content(showsChevron: false)
        }
        #else
        content(showsChevron: false)
        #endif
    }

    // MARK: - 胶囊

    private func content(showsChevron: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: effectiveIsRunning ? "mic.fill" : "mic.slash.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(hasSignal ? AppTheme.success : AppTheme.tertiaryText)

            deviceLabelView

            levelMeter

            if showsChevron {
                chevronBadge
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(.ultraThinMaterial)
                .overlay(
                    Capsule()
                        .fill(
                            LinearGradient(colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                                           startPoint: .top,
                                           endPoint: .bottom)
                        )
                )
        )
        .overlay(
            Capsule()
                .stroke(borderColor, lineWidth: 0.8)
        )
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.12), value: hasSignal)
        .animation(.easeOut(duration: 0.12), value: isHighlighted)
    }

    /// 可切换输入源时的下拉指示：强调色小圆底 + 实心下三角，
    /// 小尺寸下比线性 chevron 更容易辨认，也更像可展开的控件。
    private var chevronBadge: some View {
        ZStack {
            Circle()
                .fill(isHighlighted ? AppTheme.accent.opacity(0.24) : AppTheme.accentSoft)

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 6, weight: .bold))
                .foregroundStyle(AppTheme.accent)
                .offset(y: 0.5)
        }
        .frame(width: 15, height: 15)
        .animation(.easeOut(duration: 0.12), value: isHighlighted)
    }

    private var borderColor: Color {
        if isHighlighted {
            return AppTheme.accent.opacity(0.45)
        }
        return hasSignal ? AppTheme.success.opacity(0.3) : AppTheme.cardBorder
    }

    /// 设备名按内容取自然宽度：固定上限会先占满可用空间，
    /// 反而把两侧的标题和电平条挤到截断。macOS 窗口宽但设备名可能很长，
    /// 仍然保留 180pt 上限。
    @ViewBuilder
    private var deviceLabelView: some View {
        #if os(macOS)
        deviceLabel.frame(maxWidth: 180, alignment: .leading)
        #else
        deviceLabel
        #endif
    }

    private var deviceLabel: some View {
        Text(deviceLabelText)
            .font(.system(size: 11, weight: .medium))
            .foregroundStyle(AppTheme.secondaryText)
            .lineLimit(1)
            .truncationMode(.middle)
    }

    private var levelMeter: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(AppTheme.gaugeTrack)

                Capsule()
                    .fill(hasSignal ? AppTheme.success : AppTheme.tertiaryText.opacity(0.4))
                    .frame(width: max(3, geo.size.width * levelRatio))
            }
        }
        .frame(width: 38, height: 5)
        .animation(.easeOut(duration: 0.12), value: levelRatio)
    }

    // MARK: - 设备列表（macOS）

    #if os(macOS)
    private func devicePicker(onSelect: @escaping (String?) -> Void) -> some View {
        let defaultName = monitor.defaultDeviceUID
            .flatMap { uid in monitor.devices.first { $0.id == uid }?.name }
            ?? monitor.devices.first(where: \.isDefault)?.name

        return VStack(alignment: .leading, spacing: 2) {
            Text(L10n.tr("输入设备"))
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.horizontal, 10)
                .padding(.top, 2)
                .padding(.bottom, 4)

            pickerRow(icon: "gearshape.fill",
                      tint: AppTheme.secondaryText,
                      title: L10n.tr("系统默认"),
                      subtitle: defaultName.map { L10n.tr("当前：%@", $0) }
                          ?? L10n.tr("跟随 macOS 声音设置"),
                      isSelected: selectedDeviceUID == nil) {
                onSelect(nil)
            }

            ForEach(monitor.devices) { device in
                pickerRow(icon: device.isDefault ? "mic.fill" : "mic",
                          tint: device.isDefault ? AppTheme.accent : AppTheme.secondaryText,
                          title: device.name,
                          subtitle: device.isDefault
                              ? L10n.tr("系统默认输入")
                              : device.kindLabel,
                          isSelected: selectedDeviceUID == device.id) {
                    onSelect(device.id)
                }
            }
        }
        .padding(8)
        .frame(width: 290)
    }

    private func pickerRow(icon: String,
                           tint: Color,
                           title: String,
                           subtitle: String?,
                           isSelected: Bool,
                           action: @escaping () -> Void) -> some View {
        Button {
            action()
            showsDevicePicker = false
        } label: {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 18)

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(AppTheme.primaryText)
                        .lineLimit(1)

                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 10))
                            .foregroundStyle(AppTheme.secondaryText)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(AppTheme.accent)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AppTheme.accentSoft : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    #endif
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
        .background(GlassCardBackground(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(AppTheme.warning.opacity(0.22), lineWidth: 0.8)
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
                    .fill(role == .primary
                          ? AnyShapeStyle(AppTheme.accentGradient)
                          : AnyShapeStyle(Color.white.opacity(0.06)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(role == .primary
                            ? Color.white.opacity(0.22)
                            : Color.white.opacity(0.09),
                            lineWidth: 0.8)
            )
            .shadow(color: role == .primary ? AppTheme.accent.opacity(0.45) : .clear,
                    radius: 14, x: 0, y: 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - 开关

/// 调音页自定义开关：圆角轨道加滑动圆钮，比系统 Toggle 更贴合卡片风格。
struct TunerSwitch: View {
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                isOn.toggle()
            }
        } label: {
            ZStack {
                Capsule()
                    .fill(isOn
                          ? AnyShapeStyle(LinearGradient(colors: [Color(hex: 0x4AA3FF), Color(hex: 0x1C6BFF)],
                                                         startPoint: .top,
                                                         endPoint: .bottom))
                          : AnyShapeStyle(Color.white.opacity(0.09)))
                    .overlay(
                        Capsule()
                            .stroke(Color.white.opacity(isOn ? 0.22 : 0.07), lineWidth: 0.8)
                    )
                    .shadow(color: isOn ? Color(hex: 0x2E7CFF).opacity(0.55) : .clear,
                            radius: 9, x: 0, y: 3)

                Circle()
                    .fill(Color.white)
                    .shadow(color: Color.black.opacity(0.35), radius: 3, x: 0, y: 1)
                    .padding(2.5)
                    .offset(x: isOn ? 11 : -11)
            }
            .frame(width: 50, height: 28)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.tr("多音调音"))
        .accessibilityValue(isOn ? L10n.tr("已开启") : L10n.tr("已关闭"))
    }
}
