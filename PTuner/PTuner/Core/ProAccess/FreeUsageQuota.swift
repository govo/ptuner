//
//  FreeUsageQuota.swift
//  PTuner
//
//  免费用户的用量额度。多音调音与和弦识别各自独立计数：
//  每天 30 秒；多音调音每周累计 1 分钟，和弦识别每周累计 2 分钟。
//  Pro 用户由调用方跳过记录。
//

import Combine
import Foundation

@MainActor
final class FreeUsageQuota: ObservableObject {

    static let shared = FreeUsageQuota()

    /// 需要独立计算额度的功能。
    enum Feature: String, CaseIterable, Sendable {
        case polyphonicTuning
        case chordRecognition
    }

    /// 额度用尽的原因。周额度优先于日额度。
    enum Limit: Equatable {
        case daily
        case weekly
    }

    enum Limits {
        /// 免费用户每天可用的秒数。
        static let dailySeconds: TimeInterval = 30
        /// 免费用户每周可用的秒数，跨天累计。
        static let polyphonicWeeklySeconds: TimeInterval = 60
        static let chordWeeklySeconds: TimeInterval = 120

        static func weeklySeconds(for feature: Feature) -> TimeInterval {
            switch feature {
            case .polyphonicTuning: return polyphonicWeeklySeconds
            case .chordRecognition: return chordWeeklySeconds
            }
        }
    }

    /// 各功能当前已用尽的额度；没有条目表示仍可使用。
    @Published private(set) var exhaustions: [Feature: Limit] = [:]

    private(set) var dailyUsed: [Feature: TimeInterval] = [:]
    private(set) var weeklyUsed: [Feature: TimeInterval] = [:]

    private let defaults: UserDefaults
    private let calendar: Calendar

    init(defaults: UserDefaults = .standard,
         calendar: Calendar = .current) {
        self.defaults = defaults
        self.calendar = calendar

        for feature in Feature.allCases {
            let keys = storageKeys(for: feature)
            dailyUsed[feature] = defaults.double(forKey: keys.dayUsed)
            weeklyUsed[feature] = defaults.double(forKey: keys.weekUsed)
        }

        rollPeriodsIfNeeded(now: Date())
        updateExhaustions()
    }

    // MARK: - 查询

    func exhaustion(for feature: Feature) -> Limit? {
        exhaustions[feature]
    }

    var polyphonicExhaustion: Limit? {
        exhaustion(for: .polyphonicTuning)
    }

    var chordExhaustion: Limit? {
        exhaustion(for: .chordRecognition)
    }

    // MARK: - 对外接口

    /// 记录一次实际使用时长。只有非 Pro 用户需要调用。
    func record(_ feature: Feature, seconds: TimeInterval) {
        guard seconds > 0 else { return }

        rollPeriodsIfNeeded(now: Date())

        let daily = min(Limits.dailySeconds, (dailyUsed[feature] ?? 0) + seconds)
        let weekly = min(Limits.weeklySeconds(for: feature), (weeklyUsed[feature] ?? 0) + seconds)
        dailyUsed[feature] = daily
        weeklyUsed[feature] = weekly

        let keys = storageKeys(for: feature)
        defaults.set(daily, forKey: keys.dayUsed)
        defaults.set(weekly, forKey: keys.weekUsed)

        updateExhaustions()
    }

    /// 检查是否跨日 / 跨周并刷新额度状态。界面回到前台时调用。
    func refreshNow() {
        rollPeriodsIfNeeded(now: Date())
        updateExhaustions()
    }

    // MARK: - 周期重置

    private func rollPeriodsIfNeeded(now: Date) {
        let currentDayKey = dayKey(for: now)
        let currentWeekKey = weekKey(for: now)

        for feature in Feature.allCases {
            let keys = storageKeys(for: feature)

            let storedDayKey = defaults.string(forKey: keys.dayKey)
            if storedDayKey != currentDayKey,
               storedDayKey == nil || currentDayKey > storedDayKey! {
                dailyUsed[feature] = 0
                defaults.set(currentDayKey, forKey: keys.dayKey)
                defaults.set(0.0, forKey: keys.dayUsed)
            }
            // storedDayKey > currentDayKey 视为系统时钟回拨：保持已用额度，不恢复。

            let storedWeekKey = defaults.string(forKey: keys.weekKey)
            if storedWeekKey != currentWeekKey,
               storedWeekKey == nil || currentWeekKey > storedWeekKey! {
                weeklyUsed[feature] = 0
                defaults.set(currentWeekKey, forKey: keys.weekKey)
                defaults.set(0.0, forKey: keys.weekUsed)
            }
        }
    }

    private func updateExhaustions() {
        var next: [Feature: Limit] = [:]

        for feature in Feature.allCases {
            if (weeklyUsed[feature] ?? 0) >= Limits.weeklySeconds(for: feature) {
                next[feature] = .weekly
            } else if (dailyUsed[feature] ?? 0) >= Limits.dailySeconds {
                next[feature] = .daily
            }
        }

        if exhaustions != next {
            exhaustions = next
        }
    }

    // MARK: - 存储键

    private struct StorageKeys {
        let dayKey: String
        let dayUsed: String
        let weekKey: String
        let weekUsed: String
    }

    private func storageKeys(for feature: Feature) -> StorageKeys {
        let prefix: String
        switch feature {
        case .polyphonicTuning:
            // 保留旧键名，升级后不会丢失已用额度。
            prefix = "ptuner.quota.polyphonic"
        case .chordRecognition:
            prefix = "ptuner.quota.chord"
        }

        return StorageKeys(dayKey: "\(prefix).dayKey",
                           dayUsed: "\(prefix).dayUsed",
                           weekKey: "\(prefix).weekKey",
                           weekUsed: "\(prefix).weekUsed")
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

    func message(for feature: FreeUsageQuota.Feature) -> String {
        switch (feature, self) {
        case (.polyphonicTuning, .daily):
            return L10n.tr("免费用户每天可享 30 秒多音调音。升级 Pro，想调多久调多久。")
        case (.polyphonicTuning, .weekly):
            return L10n.tr("免费用户每周可享 1 分钟多音调音。升级 Pro，多音调音不再限量。")
        case (.chordRecognition, .daily):
            return L10n.tr("免费用户每天可享 30 秒和弦识别。升级 Pro，想弹多久识别多久。")
        case (.chordRecognition, .weekly):
            return L10n.tr("免费用户每周可享 2 分钟和弦识别。升级 Pro，和弦识别不再限量。")
        }
    }
}
