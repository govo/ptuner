//
//  FreeUsageQuota.swift
//  PTuner
//
//  免费用户的用量额度。当前只包含多音调音：每天 30 秒，每周累计 1 分钟。
//  Pro 用户由调用方跳过记录，不进入本对象。
//

import Combine
import Foundation

@MainActor
final class FreeUsageQuota: ObservableObject {

    static let shared = FreeUsageQuota()

    /// 额度用尽的原因。周额度优先于日额度。
    enum Limit: Equatable {
        case daily
        case weekly
    }

    enum Limits {
        /// 免费用户每天可用的多音调音秒数。
        static let polyphonicDailySeconds: TimeInterval = 30
        /// 免费用户每周可用的多音调音秒数，跨天累计。
        static let polyphonicWeeklySeconds: TimeInterval = 60
    }

    /// 当前已用尽的额度；nil 表示仍可使用。
    @Published private(set) var exhaustion: Limit?

    private(set) var polyphonicDailyUsed: TimeInterval = 0
    private(set) var polyphonicWeeklyUsed: TimeInterval = 0

    private let defaults: UserDefaults
    private let calendar: Calendar

    private enum Keys {
        static let dayKey = "ptuner.quota.polyphonic.dayKey"
        static let dayUsed = "ptuner.quota.polyphonic.dayUsed"
        static let weekKey = "ptuner.quota.polyphonic.weekKey"
        static let weekUsed = "ptuner.quota.polyphonic.weekUsed"
    }

    init(defaults: UserDefaults = .standard,
         calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar

        polyphonicDailyUsed = defaults.double(forKey: Keys.dayUsed)
        polyphonicWeeklyUsed = defaults.double(forKey: Keys.weekUsed)

        rollPeriodsIfNeeded(now: Date())
        updateExhaustion()
    }

    // MARK: - 对外接口

    /// 记录一次多音调音的实际使用时长。只有非 Pro 用户需要调用。
    func recordPolyphonic(seconds: TimeInterval) {
        guard seconds > 0 else { return }

        rollPeriodsIfNeeded(now: Date())
        polyphonicDailyUsed = min(Limits.polyphonicDailySeconds,
                                  polyphonicDailyUsed + seconds)
        polyphonicWeeklyUsed = min(Limits.polyphonicWeeklySeconds,
                                   polyphonicWeeklyUsed + seconds)

        defaults.set(polyphonicDailyUsed, forKey: Keys.dayUsed)
        defaults.set(polyphonicWeeklyUsed, forKey: Keys.weekUsed)

        updateExhaustion()
    }

    /// 检查是否跨日 / 跨周并刷新额度状态。界面回到前台时调用。
    func refreshNow() {
        rollPeriodsIfNeeded(now: Date())
        updateExhaustion()
    }

    // MARK: - 周期重置

    private func rollPeriodsIfNeeded(now: Date) {
        let currentDayKey = dayKey(for: now)
        let storedDayKey = defaults.string(forKey: Keys.dayKey)

        if storedDayKey != currentDayKey,
           storedDayKey == nil || currentDayKey > storedDayKey! {
            polyphonicDailyUsed = 0
            defaults.set(currentDayKey, forKey: Keys.dayKey)
            defaults.set(0.0, forKey: Keys.dayUsed)
        }
        // storedDayKey > currentDayKey 视为系统时钟回拨：保持已用额度，不恢复。

        let currentWeekKey = weekKey(for: now)
        let storedWeekKey = defaults.string(forKey: Keys.weekKey)

        if storedWeekKey != currentWeekKey,
           storedWeekKey == nil || currentWeekKey > storedWeekKey! {
            polyphonicWeeklyUsed = 0
            defaults.set(currentWeekKey, forKey: Keys.weekKey)
            defaults.set(0.0, forKey: Keys.weekUsed)
        }
    }

    private func updateExhaustion() {
        let next: Limit?
        if polyphonicWeeklyUsed >= Limits.polyphonicWeeklySeconds {
            next = .weekly
        } else if polyphonicDailyUsed >= Limits.polyphonicDailySeconds {
            next = .daily
        } else {
            next = nil
        }

        if exhaustion != next {
            exhaustion = next
        }
    }

    // MARK: - 日期键

    private func dayKey(for date: Date) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d",
                      components.year ?? 0,
                      components.month ?? 0,
                      components.day ?? 0)
    }

    /// ISO 周键：周一为一周开始，保证跨年时仍然单调可比较。
    private func weekKey(for date: Date) -> String {
        var iso = Calendar(identifier: .iso8601)
        iso.timeZone = calendar.timeZone
        let components = iso.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)
        return String(format: "%04d-W%02d",
                      components.yearForWeekOfYear ?? 0,
                      components.weekOfYear ?? 0)
    }
}

// MARK: - 文案

extension FreeUsageQuota.Limit {

    var title: String {
        switch self {
        case .daily: return L10n.tr("今天的免费额度已用完")
        case .weekly: return L10n.tr("本周的免费额度已用完")
        }
    }

    var message: String {
        switch self {
        case .daily:
            return L10n.tr("免费用户每天可享 30 秒多音调音。升级 Pro，想调多久调多久。")
        case .weekly:
            return L10n.tr("免费用户每周可享 1 分钟多音调音。升级 Pro，多音调音不再限量。")
        }
    }
}
