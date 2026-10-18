#if DEBUG
import Foundation

#if os(macOS)
import AppKit
#endif

/// App Store 截图专用：通过启动参数注入演示数据，避免依赖真实麦克风输入。
///
/// 只在 DEBUG 构建中编译，正式包不包含任何相关代码。
/// 用法：
///   -screenshotScene single|multi|library|custom|chord
///   -screenshotTab   tuner|chord|instruments|settings
enum ScreenshotDemo {
    enum Scene: String {
        case single
        case multi
        case library
        case custom
        case chord
    }

    private static let arguments = ProcessInfo.processInfo.arguments

    /// 截图模式下不启动真实音频输入。
    static var isActive: Bool {
        value(for: "-screenshotScene") != nil
    }

    static var scene: Scene? {
        value(for: "-screenshotScene").flatMap(Scene.init(rawValue:))
    }

    static var initialTab: MainTab? {
        value(for: "-screenshotTab").flatMap(MainTab.init(rawValue:))
    }

    /// 输入状态胶囊在截图里固定显示为「内置麦克风 · 运行中」。
    static var inputDeviceName: String {
        L10n.tr("内置麦克风")
    }

    static let inputLevel: Float = 0.028

    // MARK: - 数据注入

    @MainActor
    static func prepare(live: TunerRealtimeState, library: InstrumentLibrary) {
        guard let scene else { return }

        switch scene {
        case .single:
            selectGuitarStandard(library)
            live.liveMidi = 64.02
            live.liveConfidence = 0.96
            live.analyzedSeconds = 12.4
            live.level = inputLevel

        case .multi:
            selectGuitarStandard(library)
            live.polyReadouts = guitarReadouts
            live.polyAnalyzedSeconds = 8.2
            live.polyInferenceMs = 23
            live.level = inputLevel

        case .chord:
            live.polyReadouts = cMajorReadouts
            live.polyAnalyzedSeconds = 6.8
            live.polyInferenceMs = 21
            live.level = inputLevel

        case .library, .custom:
            break
        }
    }

    /// 自定义调弦演示草稿：直接用吉他标准音作为起点，
    /// 前三根弦带上不同的音分偏移，让截图能看出微调能力。
    static func customDraft(in library: InstrumentLibrary) -> TuningPreset {
        var draft = library.makeDraft(instrument: InstrumentCatalog.instrument(id: "guitar"))
        let offsets = [-8.0, 5.0, -3.0]
        for (index, offset) in offsets.enumerated() where draft.strings.indices.contains(index) {
            draft.strings[index].centsOffset = offset
        }
        return draft
    }

    // MARK: - macOS 窗口

    /// 自定义调弦编辑器在 macOS 上是表单尺寸的 sheet，普通窗口高度只能露出
    /// 一行弦设置。截图时进入全屏窗口，让 sheet 获得足够高度展示多行。
    @MainActor
    static func enterFullScreenIfNeeded() {
        #if os(macOS)
        guard scene == .custom else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(250))
            NSApp.activate(ignoringOtherApps: true)
            try? await Task.sleep(for: .milliseconds(300))
            let mainWindow = NSApp.windows
                .filter { $0.isVisible && $0.frame.width > 500 }
                .max { $0.frame.width < $1.frame.width }
            mainWindow?.toggleFullScreen(nil)
        }
        #endif
    }

    // MARK: - 演示数据

    private static func selectGuitarStandard(_ library: InstrumentLibrary) {
        guard library.selectedPresetID != "guitar.standard",
              let preset = library.preset(id: "guitar.standard") else { return }
        library.select(preset)
    }

    /// 吉他标准调弦六根弦，偏差控制在 ±3 音分内。
    private static var guitarReadouts: [TunerPolyReadout] {
        [
            TunerPolyReadout(id: 0, midiPitch: 40, cents: -1.8, amplitude: 0.34),
            TunerPolyReadout(id: 1, midiPitch: 45, cents: 2.4, amplitude: 0.31),
            TunerPolyReadout(id: 2, midiPitch: 50, cents: 0.7, amplitude: 0.29),
            TunerPolyReadout(id: 3, midiPitch: 55, cents: -2.6, amplitude: 0.27),
            TunerPolyReadout(id: 4, midiPitch: 59, cents: 1.2, amplitude: 0.26),
            TunerPolyReadout(id: 5, midiPitch: 64, cents: -0.9, amplitude: 0.25)
        ]
    }

    private static var cMajorReadouts: [TunerPolyReadout] {
        [
            TunerPolyReadout(id: 0, midiPitch: 60, cents: 1.4, amplitude: 0.36),
            TunerPolyReadout(id: 1, midiPitch: 64, cents: -1.1, amplitude: 0.32),
            TunerPolyReadout(id: 2, midiPitch: 67, cents: 0.6, amplitude: 0.30)
        ]
    }

    // MARK: - 参数解析

    private static func value(for flag: String) -> String? {
        guard let index = arguments.firstIndex(of: flag),
              arguments.indices.contains(index + 1) else { return nil }
        let value = arguments[index + 1]
        return value.hasPrefix("-") ? nil : value
    }
}
#endif
