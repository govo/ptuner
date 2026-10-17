//
//  ProAccessController.swift
//  PTuner
//
//  应用内 Pro 权益判断的唯一入口。
//
//  正常构建始终以 RevenueCat 的真实权益为准。Debug 构建额外提供一个
//  「跳过 Pro 权益校验」的调试开关，默认开启，方便开发阶段直接使用 Pro 功能。
//  Release 构建不包含该开关，行为与线上完全一致。
//

import Combine
import Foundation
import RevenueCatPaywallKit

@MainActor
final class ProAccessController: ObservableObject {

    static let shared = ProAccessController()

    /// 调试开关在 UserDefaults 中的键，仅 Debug 构建读写。
    static let debugSkipEntitlementKey = "debug.pro.skipEntitlement"

    /// 是否跳过 Pro 权益校验。Release 构建恒为 false。
    @Published var skipsEntitlementCheck: Bool {
        didSet {
            #if DEBUG
            UserDefaults.standard.set(skipsEntitlementCheck, forKey: Self.debugSkipEntitlementKey)
            #endif
        }
    }

    private init() {
        #if DEBUG
        // 未写入过设置时默认开启：开发者 clone 后即可直接使用 Pro 功能。
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.debugSkipEntitlementKey) == nil {
            skipsEntitlementCheck = true
            defaults.set(true, forKey: Self.debugSkipEntitlementKey)
        } else {
            skipsEntitlementCheck = defaults.bool(forKey: Self.debugSkipEntitlementKey)
        }
        #else
        skipsEntitlementCheck = false
        #endif
    }

    /// 所有 Pro 功能门控都必须经由这里判断。
    func isPro(_ manager: RevenueCatPaywallManager) -> Bool {
        if skipsEntitlementCheck {
            return true
        }
        return manager.hasActiveEntitlement
    }
}
