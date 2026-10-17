#if os(macOS)

import Combine
import CoreAudio
import Foundation

/// macOS 输入设备监听。
///
/// 监听 Core Audio 的系统级属性：
/// - `kAudioHardwarePropertyDevices`：设备新增或移除；
/// - `kAudioHardwarePropertyDefaultInputDevice`：系统默认输入变化。
///
/// 变化后重新枚举设备并发布，界面与调音器据此实时更新，
/// 不再依赖手动刷新。
@MainActor
final class AudioInputDeviceMonitor: ObservableObject {

    static let shared = AudioInputDeviceMonitor()

    /// 当前所有可用输入设备。
    @Published private(set) var devices: [AudioInputDevice] = []
    /// 系统默认输入设备的 UID。
    @Published private(set) var defaultDeviceUID: String?
    /// 本次变化中新增的设备，用于界面提示。
    @Published private(set) var recentlyAdded: [AudioInputDevice] = []
    /// 每次设备列表或默认输入发生变化时递增。
    @Published private(set) var changeToken = 0

    private final class Listener {
        var address: AudioObjectPropertyAddress
        let block: AudioObjectPropertyListenerBlock

        init(address: AudioObjectPropertyAddress, block: @escaping AudioObjectPropertyListenerBlock) {
            self.address = address
            self.block = block
        }
    }

    private var listeners: [Listener] = []
    private var isMonitoring = false
    private var hasLoadedOnce = false

    private init() {}

    // MARK: - 生命周期

    func start() {
        guard !isMonitoring else { return }
        isMonitoring = true

        addListener(kAudioHardwarePropertyDevices)
        addListener(kAudioHardwarePropertyDefaultInputDevice)
        refresh()
    }

    func stop() {
        guard isMonitoring else { return }
        isMonitoring = false

        for listener in listeners {
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &listener.address,
                DispatchQueue.main,
                listener.block
            )
        }
        listeners.removeAll()
    }

    // MARK: - 刷新

    func refresh() {
        let updated = AudioInputDevices.all()
        let defaultUID = AudioInputDevices.defaultDeviceUID()

        guard !hasLoadedOnce || updated != devices || defaultUID != defaultDeviceUID else {
            return
        }

        if hasLoadedOnce {
            let previousIDs = Set(devices.map(\.id))
            recentlyAdded = updated.filter { !previousIDs.contains($0.id) }
        } else {
            recentlyAdded = []
            hasLoadedOnce = true
        }

        devices = updated
        defaultDeviceUID = defaultUID
        changeToken &+= 1
    }

    // MARK: - Core Audio 监听

    private func addListener(_ selector: AudioObjectPropertySelector) {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        let block: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }

        let status = AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &address,
            DispatchQueue.main,
            block
        )

        if status == noErr {
            listeners.append(Listener(address: address, block: block))
        }
    }
}

#endif
