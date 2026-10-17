import Combine
import SwiftUI

/// 一级导航目标。iOS 使用底部标签栏，macOS 使用侧边栏，共用同一套枚举。
enum MainTab: String, CaseIterable, Identifiable, Hashable {
    case tuner
    case chord
    case instruments
    case management
    case settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .tuner: return "调音器"
        case .chord: return "和弦"
        case .instruments: return "乐器"
        case .management: return "管理"
        case .settings: return "设置"
        }
    }

    var systemImage: String {
        switch self {
        case .tuner: return "tuningfork"
        case .chord: return "music.note.list"
        case .instruments: return "guitars"
        case .management: return "square.grid.2x2"
        case .settings: return "gearshape"
        }
    }
}

@MainActor
final class AppRouter: ObservableObject {
    @Published var selectedTab: MainTab = .tuner

    func showTuner() {
        selectedTab = .tuner
    }

    func showChord() {
        selectedTab = .chord
    }

    func showInstruments() {
        selectedTab = .instruments
    }

    func showManagement() {
        selectedTab = .management
    }

    func showSettings() {
        selectedTab = .settings
    }
}

// MARK: - 跨平台系统跳转

enum PlatformActions {
    /// 打开系统设置中的麦克风权限页。
    static func openMicrophoneSettings() {
        #if os(macOS)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
            NSWorkspace.shared.open(url)
        }
        #else
        if let url = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}

#if os(macOS)
import AppKit
#else
import UIKit
#endif
