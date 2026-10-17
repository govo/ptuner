//
//  ProGatedButton.swift
//  PTuner
//
//  Pro 功能入口按钮。权益判断统一走 ProAccessController，
//  使 Debug 调试开关对入口按钮和锁标同样生效。
//

import RevenueCatPaywallKit
import SwiftUI

struct ProGatedButton<Label: View>: View {
    @ObservedObject private var proAccess = ProAccessController.shared

    private let manager: RevenueCatPaywallManager
    private let featureID: String?
    private let marketingMessage: String?
    private let lockPlacement: ProLockPlacement
    private let action: () -> Void
    private let label: () -> Label

    init(
        manager: RevenueCatPaywallManager,
        featureID: String? = nil,
        marketingMessage: String? = nil,
        lockPlacement: ProLockPlacement = .topTrailing,
        action: @escaping () -> Void,
        @ViewBuilder label: @escaping () -> Label
    ) {
        self.manager = manager
        self.featureID = featureID
        self.marketingMessage = marketingMessage
        self.lockPlacement = lockPlacement
        self.action = action
        self.label = label
    }

    var body: some View {
        Button {
            if proAccess.isPro(manager) {
                action()
            } else {
                Task {
                    await manager.presentPaywall(
                        featureID: featureID,
                        marketingMessage: marketingMessage
                    )
                }
            }
        } label: {
            label()
                .proLocked(
                    !proAccess.isPro(manager),
                    placement: lockPlacement
                )
        }
        .buttonStyle(.plain)
    }
}
