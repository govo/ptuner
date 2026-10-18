import SwiftUI

// MARK: - 宽屏布局环境

private struct WideLayoutKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// 是否使用与 macOS 一致的双栏布局。
    /// 页面据此把纵向堆叠的内容改成左右两栏。
    var usesWideLayout: Bool {
        get { self[WideLayoutKey.self] }
        set { self[WideLayoutKey.self] = newValue }
    }
}
