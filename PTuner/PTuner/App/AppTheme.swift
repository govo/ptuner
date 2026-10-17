import SwiftUI

#if os(macOS)
import AppKit
#else
import UIKit
#endif

/// App 全局视觉基线。支持亮色与暗色，各页面统一从这里取色。
enum AppTheme {
    static let background = Color(light: 0xF3F4F7, dark: 0x0C0F14)
    static let surface = Color(light: 0xFFFFFF, dark: 0x151A21)
    static let surfaceElevated = Color(light: 0xEFF1F5, dark: 0x1D242D)
    static let segmentBackground = Color(light: 0xE8EAEF, dark: 0x11161C)
    static let controlBackground = Color(light: 0xF2F3F6, dark: 0x222A34)

    static let accent = Color(light: 0x2F6BFF, dark: 0x4C8DFF)
    static let accentSoft = accent.opacity(0.14)
    static let onAccent = Color.white

    static let primaryText = Color(light: 0x111827, dark: 0xF4F7FB)
    static let secondaryText = Color(light: 0x6B7280, dark: 0x94A3B8)
    static let tertiaryText = Color(light: 0x9CA3AF, dark: 0x64748B)

    static let success = Color(light: 0x17A35C, dark: 0x34D487)
    static let warning = Color(light: 0xE18C00, dark: 0xF5A524)
    static let danger = Color(light: 0xE5484D, dark: 0xFF6369)

    static let cardBorder = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.07)
    static let subtleBorder = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.04)
    static let divider = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.07)
    static let gaugeTrack = Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.08)
    static let shadow = Color.black.opacity(0.16)

    /// 乐器分类的识别色。
    static func tint(for kind: InstrumentKind) -> Color {
        switch kind {
        case .guitar: return accent
        case .bass: return Color(light: 0x7C5CFF, dark: 0xA98BFF)
        case .ukulele: return Color(light: 0xE07A1F, dark: 0xF5A524)
        case .other: return Color(light: 0x0E9F9A, dark: 0x2DD4BF)
        }
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
