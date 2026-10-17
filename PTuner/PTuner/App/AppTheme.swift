import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// App 全局视觉基线。支持亮色与暗色，各页面统一从这里取色。
///
/// 当前版本全局锁定深色外观（`RootView` 中的 `preferredColorScheme(.dark)`），
/// 亮色值先保留在 token 里，后续恢复亮色主题时不需要重新设计整套颜色。
enum AppTheme {
    static let background = Color(light: 0xF3F4F7, dark: 0x080B10)
    static let surface = Color(light: 0xFFFFFF, dark: 0x161B22)
    static let surfaceElevated = Color(light: 0xEFF1F5, dark: 0x1C222B)
    static let segmentBackground = Color(light: 0xE8EAEF, dark: 0x0B0E13)
    static let controlBackground = Color(light: 0xF2F3F6, dark: 0x232A33)

    static let accent = Color(light: 0x2F6BFF, dark: 0x4C8DFF)
    static let accentSoft = accent.opacity(0.14)
    static let onAccent = Color.white

    static let primaryText = Color(light: 0x111827, dark: 0xF5F8FC)
    static let secondaryText = Color(light: 0x6B7280, dark: 0x98A6B8)
    static let tertiaryText = Color(light: 0x9CA3AF, dark: 0x627082)

    static let success = Color(light: 0x17A35C, dark: 0x35E39B)
    static let warning = Color(light: 0xE18C00, dark: 0xF7B54A)
    static let danger = Color(light: 0xE5484D, dark: 0xFF6B70)

    static let cardBorder = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.07)
    static let subtleBorder = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.04)
    static let divider = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.08)
    static let gaugeTrack = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.09)
    static let shadow = Color.black.opacity(0.16)

    // MARK: - 毛玻璃

    /// 卡片顶部与底部的高光渐变，叠在 `ultraThinMaterial` 上形成玻璃质感。
    /// 带一点冷蓝，避免纯白透明叠加后发灰。
    static let glassTop = Color(hex: 0xC9D8EE).opacity(0.065)
    static let glassBottom = Color(hex: 0x9BB0CC).opacity(0.020)
    /// 卡片描边：顶部亮、底部暗，模拟受光边缘。
    static let glassStrokeTop = Color(hex: 0xD6E4F5).opacity(0.15)
    static let glassStrokeBottom = Color.white.opacity(0.03)
    /// 控件小面积高光（开关、步进器、图标底座）。
    static let controlHighlight = Color.white.opacity(0.10)

    // MARK: - 调音表

    static let gaugeBlue = Color(hex: 0x4EA1FF)
    static let gaugeTeal = Color(hex: 0x3BD9C6)
    static let gaugeGreen = Color(hex: 0x36E39B)
    static let gaugeAmber = Color(hex: 0xE9D45F)
    static let gaugeOrange = Color(hex: 0xFF9E45)

    /// 弧形刻度使用的左右渐变：冷蓝 → 青 → 绿 → 琥珀 → 橙。
    /// 用水平线性渐变而不是角向渐变，弧顶正好落在绿色上，与参考图一致。
    static let gaugeLinear = LinearGradient(
        gradient: Gradient(stops: [
            .init(color: gaugeBlue, location: 0.00),
            .init(color: gaugeTeal, location: 0.26),
            .init(color: gaugeGreen, location: 0.50),
            .init(color: gaugeAmber, location: 0.76),
            .init(color: gaugeOrange, location: 1.00)
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )

    /// 主按钮的蓝色渐变。
    static let accentGradient = LinearGradient(
        colors: [Color(hex: 0x3B82F6), Color(hex: 0x2563EB)],
        startPoint: .top,
        endPoint: .bottom
    )

    /// 乐器识别色由 `Instruments.json` 提供：优先乐器专属色，其次所属族的颜色。
    static func tint(for instrument: InstrumentDefinition) -> Color {
        if let tint = instrument.tint {
            return Self.tint(hex: tint, fallback: Self.tint(for: instrument.family))
        }
        return Self.tint(for: instrument.family)
    }

    static func tint(for family: InstrumentFamily?) -> Color {
        guard let family else { return accent }
        return tint(hex: family.tint, fallback: accent)
    }

    static func tint(forInstrumentID id: String) -> Color {
        guard let instrument = InstrumentCatalog.instrument(id: id) else {
            return tint(for: InstrumentCatalog.fallbackFamily)
        }
        return tint(for: instrument)
    }

    static func tint(hex: String, fallback: Color) -> Color {
        let cleaned = hex
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "#", with: "")
        guard let value = UInt32(cleaned, radix: 16) else { return fallback }
        return Color(hex: value)
    }
}

// MARK: - 背景

/// 全局背景：近黑冷色底，叠加极淡的顶部蓝光与中部绿光。
/// 光晕只负责营造氛围，不参与信息表达，因此透明度压得很低。
struct AppBackground: View {
    var body: some View {
        ZStack {
            AppTheme.background

            RadialGradient(colors: [AppTheme.accent.opacity(0.10), .clear],
                           center: UnitPoint(x: 0.5, y: -0.12),
                           startRadius: 0,
                           endRadius: 460)

            RadialGradient(colors: [AppTheme.gaugeGreen.opacity(0.055), .clear],
                           center: UnitPoint(x: 0.5, y: 0.42),
                           startRadius: 0,
                           endRadius: 380)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

// MARK: - 毛玻璃卡片

/// 统一的毛玻璃卡片底：材质模糊 + 低透白色渐变 + 受光描边。
struct GlassCardBackground: View {
    var cornerRadius: CGFloat = 22

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(.ultraThinMaterial)
            // 深色模式下 ultraThinMaterial 会偏亮，压一层暗色让卡片回到参考图的深灰蓝。
            .overlay(
                shape.fill(Color(hex: 0x070A0E).opacity(0.46))
            )
            .overlay(
                shape.fill(
                    LinearGradient(colors: [AppTheme.glassTop, AppTheme.glassBottom],
                                   startPoint: .top,
                                   endPoint: .bottom)
                )
            )
            .overlay(
                shape.strokeBorder(
                    LinearGradient(colors: [AppTheme.glassStrokeTop, AppTheme.glassStrokeBottom],
                                   startPoint: .top,
                                   endPoint: .bottom),
                    lineWidth: 0.8
                )
            )
    }
}

/// 小型控件底座（图标、搜索框、步进器）复用的玻璃填充。
struct GlassControlBackground: View {
    var cornerRadius: CGFloat = 12

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        shape
            .fill(Color.white.opacity(0.055))
            .overlay(
                shape.strokeBorder(Color.white.opacity(0.09), lineWidth: 0.8)
            )
    }
}

// MARK: - 动态颜色

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(
            light: Color(hex: light),
            dark: Color(hex: dark)
        )
    }

    init(light: Color, dark: Color) {
        #if os(macOS)
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return NSColor(isDark ? dark : light)
        })
        #else
        self.init(uiColor: UIColor { traits in
            UIColor(traits.userInterfaceStyle == .dark ? dark : light)
        })
        #endif
    }

    init(hex: UInt32) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: 1
        )
    }
}
