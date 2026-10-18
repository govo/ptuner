import Combine
import Foundation

nonisolated enum CentsPrecision: String, CaseIterable, Identifiable, Sendable {
    case integer
    case tenth

    var id: String { rawValue }

    var title: String {
        switch self {
        case .integer: return L10n.tr("整数 Cents")
        case .tenth: return "0.1 Cents"
        }
    }

    var digits: Int {
        self == .integer ? 0 : 1
    }

    func format(_ cents: Double) -> String {
        String(format: "%+.\(digits)f", cents)
    }
}

nonisolated enum IndicatorStyle: String, CaseIterable, Identifiable, Sendable {
    case needle
    case bar

    var id: String { rawValue }

    var title: String {
        switch self {
        case .needle: return L10n.tr("指针式")
        case .bar: return L10n.tr("横向音准条")
        }
    }
}

nonisolated enum DisplayStability: String, CaseIterable, Identifiable, Sendable {
    case fast
    case balanced
    case stable

    var id: String { rawValue }

    var title: String {
        switch self {
        case .fast: return L10n.tr("快速")
        case .balanced: return L10n.tr("平衡")
        case .stable: return L10n.tr("稳定")
        }
    }

    /// 传给 TunerController 的显示平滑系数。
    var smoothingFactor: Double {
        switch self {
        case .fast: return 0.75
        case .balanced: return 0.35
        case .stable: return 0.15
        }
    }
}

/// 全局调音设置。参考音高会影响所有调音模式。
@MainActor
final class TunerSettings: ObservableObject {

    static let minimumReferencePitch = 400.0
    static let maximumReferencePitch = 480.0

    @Published var referencePitch: Double {
        didSet { defaults.set(referencePitch, forKey: Keys.referencePitch) }
    }

    @Published var centsPrecision: CentsPrecision {
        didSet { defaults.set(centsPrecision.rawValue, forKey: Keys.centsPrecision) }
    }

    @Published var indicatorStyle: IndicatorStyle {
        didSet { defaults.set(indicatorStyle.rawValue, forKey: Keys.indicatorStyle) }
    }

    @Published var stability: DisplayStability {
        didSet { defaults.set(stability.rawValue, forKey: Keys.stability) }
    }

    /// 点击音名试听时使用的参考音波形。
    @Published var referenceToneWaveform: ReferenceToneWaveform {
        didSet { defaults.set(referenceToneWaveform.rawValue, forKey: Keys.referenceToneWaveform) }
    }

    @Published var maxPolyphony: Int {
        didSet { defaults.set(maxPolyphony, forKey: Keys.maxPolyphony) }
    }

    /// macOS 下选择的 Core Audio 输入设备 UID；nil 表示跟随系统默认。
    @Published var preferredInputDeviceUID: String? {
        didSet { defaults.set(preferredInputDeviceUID, forKey: Keys.preferredInputDeviceUID) }
    }

    private let defaults: UserDefaults

    private enum Keys {
        static let referencePitch = "ptuner.settings.referencePitch"
        static let centsPrecision = "ptuner.settings.centsPrecision"
        static let indicatorStyle = "ptuner.settings.indicatorStyle"
        static let stability = "ptuner.settings.stability"
        static let referenceToneWaveform = "ptuner.settings.referenceToneWaveform"
        static let maxPolyphony = "ptuner.settings.maxPolyphony"
        static let preferredInputDeviceUID = "ptuner.settings.preferredInputDeviceUID"
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let storedPitch = defaults.double(forKey: Keys.referencePitch)
        referencePitch = storedPitch > 0 ? storedPitch : 440

        centsPrecision = CentsPrecision(rawValue: defaults.string(forKey: Keys.centsPrecision) ?? "") ?? .tenth
        indicatorStyle = IndicatorStyle(rawValue: defaults.string(forKey: Keys.indicatorStyle) ?? "") ?? .needle
        stability = DisplayStability(rawValue: defaults.string(forKey: Keys.stability) ?? "") ?? .balanced
        referenceToneWaveform = ReferenceToneWaveform(rawValue: defaults.string(forKey: Keys.referenceToneWaveform) ?? "") ?? .square

        let storedPolyphony = defaults.integer(forKey: Keys.maxPolyphony)
        maxPolyphony = (2...12).contains(storedPolyphony) ? storedPolyphony : 6

        preferredInputDeviceUID = defaults.string(forKey: Keys.preferredInputDeviceUID)
    }

    func setReferencePitch(_ value: Double) {
        let clamped = min(Self.maximumReferencePitch, max(Self.minimumReferencePitch, value))
        referencePitch = (clamped * 10).rounded() / 10
    }

    func setMaxPolyphony(_ value: Int) {
        maxPolyphony = min(12, max(2, value))
    }

    /// 把设置同步到调音器。
    func apply(to tuner: TunerController) {
        tuner.setDisplaySmoothing(stability.smoothingFactor)
        tuner.setMaxPolyphony(maxPolyphony)
        tuner.setPreferredInputDeviceUID(preferredInputDeviceUID)
    }
}
