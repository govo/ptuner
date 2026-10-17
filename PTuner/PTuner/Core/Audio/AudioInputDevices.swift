import Foundation

#if os(macOS)
import CoreAudio
#else
import AVFoundation
#endif

nonisolated struct AudioInputDevice: Identifiable, Hashable, Sendable {
    /// macOS 为设备 UID，iOS 为音频端口 UID。
    let id: String
    let name: String
    let isDefault: Bool
    let isAvailable: Bool
    let kindLabel: String?
}

#if os(macOS)

/// macOS Core Audio 输入设备枚举与选择。
nonisolated enum AudioInputDevices {

    static func all() -> [AudioInputDevice] {
        guard let defaultID = defaultInputDeviceID() else { return [] }
        return deviceIDs().compactMap { deviceID in
            guard inputChannelCount(deviceID) > 0 else { return nil }
            let uid = stringProperty(deviceID, selector: kAudioDevicePropertyDeviceUID) ?? "device-\(deviceID)"
            let name = stringProperty(deviceID, selector: kAudioObjectPropertyName) ?? "未命名输入设备"
            return AudioInputDevice(id: uid,
                                    name: name,
                                    isDefault: deviceID == defaultID,
                                    isAvailable: true,
                                    kindLabel: transportLabel(deviceID))
        }
    }

    static func defaultDeviceUID() -> String? {
        guard let id = defaultInputDeviceID() else { return nil }
        return stringProperty(id, selector: kAudioDevicePropertyDeviceUID)
    }

    static func deviceID(forUID uid: String) -> AudioDeviceID? {
        deviceIDs().first { stringProperty($0, selector: kAudioDevicePropertyDeviceUID) == uid }
    }

    // MARK: - Core Audio

    private static func systemObject() -> AudioObjectID {
        AudioObjectID(kAudioObjectSystemObject)
    }

    private static func address(_ selector: AudioObjectPropertySelector,
                                scope: AudioObjectPropertyScope = kAudioObjectPropertyScopeGlobal,
                                element: AudioObjectPropertyElement = kAudioObjectPropertyElementMain) -> AudioObjectPropertyAddress {
        AudioObjectPropertyAddress(mSelector: selector, mScope: scope, mElement: element)
    }

    static func deviceIDs() -> [AudioDeviceID] {
        var addr = address(kAudioHardwarePropertyDevices)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(systemObject(), &addr, 0, nil, &size) == noErr,
              size > 0 else { return [] }

        let count = Int(size) / MemoryLayout<AudioDeviceID>.size
        var ids = [AudioDeviceID](repeating: 0, count: count)
        let status = ids.withUnsafeMutableBytes { buffer in
            AudioObjectGetPropertyData(systemObject(), &addr, 0, nil, &size, buffer.baseAddress!)
        }
        guard status == noErr else { return [] }
        return ids
    }

    static func defaultInputDeviceID() -> AudioDeviceID? {
        var addr = address(kAudioHardwarePropertyDefaultInputDevice)
        var deviceID = AudioDeviceID(0)
        var size = UInt32(MemoryLayout<AudioDeviceID>.size)
        guard AudioObjectGetPropertyData(systemObject(), &addr, 0, nil, &size, &deviceID) == noErr,
              deviceID != 0 else { return nil }
        return deviceID
    }

    private static func inputChannelCount(_ deviceID: AudioDeviceID) -> Int {
        var addr = address(kAudioDevicePropertyStreamConfiguration,
                           scope: kAudioObjectPropertyScopeInput)
        var size: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &addr, 0, nil, &size) == noErr,
              size > 0 else { return 0 }

        let raw = UnsafeMutableRawPointer.allocate(
            byteCount: Int(size),
            alignment: MemoryLayout<AudioBufferList>.alignment
        )
        defer { raw.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, raw) == noErr else { return 0 }
        let buffers = UnsafeMutableAudioBufferListPointer(raw.assumingMemoryBound(to: AudioBufferList.self))
        return buffers.reduce(0) { $0 + Int($1.mNumberChannels) }
    }

    private static func stringProperty(_ deviceID: AudioDeviceID,
                                       selector: AudioObjectPropertySelector) -> String? {
        var addr = address(selector)
        var value: CFString = "" as CFString
        var size = UInt32(MemoryLayout<CFString>.size)
        let status = withUnsafeMutablePointer(to: &value) { pointer in
            AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, pointer)
        }
        guard status == noErr else { return nil }
        let string = value as String
        return string.isEmpty ? nil : string
    }

    private static func transportLabel(_ deviceID: AudioDeviceID) -> String? {
        var addr = address(kAudioDevicePropertyTransportType)
        var transport: UInt32 = 0
        var size = UInt32(MemoryLayout<UInt32>.size)
        guard AudioObjectGetPropertyData(deviceID, &addr, 0, nil, &size, &transport) == noErr else {
            return nil
        }

        switch transport {
        case kAudioDeviceTransportTypeBuiltIn: return "内置"
        case kAudioDeviceTransportTypeUSB: return "USB"
        case kAudioDeviceTransportTypeBluetooth, kAudioDeviceTransportTypeBluetoothLE: return "蓝牙"
        case kAudioDeviceTransportTypeAggregate: return "聚合设备"
        case kAudioDeviceTransportTypeVirtual: return "虚拟设备"
        case kAudioDeviceTransportTypeHDMI: return "HDMI"
        case kAudioDeviceTransportTypeDisplayPort: return "DisplayPort"
        case kAudioDeviceTransportTypeThunderbolt: return "雷雳"
        default: return nil
        }
    }
}

#else

/// iOS 的输入来源由系统决定，这里只做只读展示。
nonisolated enum AudioInputDevices {

    static func all() -> [AudioInputDevice] {
        let session = AVAudioSession.sharedInstance()
        let currentUIDs = Set(session.currentRoute.inputs.map(\.uid))

        if let available = session.availableInputs, !available.isEmpty {
            return available.map { port in
                AudioInputDevice(id: port.uid,
                                 name: port.portName,
                                 isDefault: currentUIDs.contains(port.uid),
                                 isAvailable: true,
                                 kindLabel: label(for: port.portType))
            }
        }

        return session.currentRoute.inputs.map { port in
            AudioInputDevice(id: port.uid,
                             name: port.portName,
                             isDefault: true,
                             isAvailable: true,
                             kindLabel: label(for: port.portType))
        }
    }

    static func currentInputName() -> String? {
        AVAudioSession.sharedInstance().currentRoute.inputs.first?.portName
    }

    private static func label(for port: AVAudioSession.Port) -> String? {
        switch port {
        case .builtInMic: return "内置"
        case .usbAudio: return "USB"
        case .bluetoothHFP, .bluetoothLE: return "蓝牙"
        case .headsetMic: return "耳机麦克风"
        case .lineIn: return "线路输入"
        default: return nil
        }
    }
}

#endif
