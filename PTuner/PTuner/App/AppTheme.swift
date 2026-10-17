import SwiftUI

/// App 全局视觉基线。后续界面统一从这里取色，避免各页面散落硬编码色值。
enum AppTheme {
    static let background = Color(red: 0.045, green: 0.055, blue: 0.075)
    static let surface = Color(red: 0.10, green: 0.115, blue: 0.145)
    static let surfaceElevated = Color(red: 0.14, green: 0.16, blue: 0.20)
    static let accent = Color(red: 0.25, green: 0.82, blue: 0.88)
    static let accentSoft = accent.opacity(0.16)
    static let primaryText = Color.white
    static let secondaryText = Color.white.opacity(0.62)
    static let success = Color(red: 0.34, green: 0.86, blue: 0.52)
    static let warning = Color(red: 0.98, green: 0.72, blue: 0.25)
    static let danger = Color(red: 0.95, green: 0.36, blue: 0.36)
}
