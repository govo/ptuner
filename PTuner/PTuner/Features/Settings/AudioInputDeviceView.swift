#if os(macOS)
import SwiftUI

/// macOS 音频输入设备选择。
struct AudioInputDeviceView: View {
    @EnvironmentObject private var settings: TunerSettings
    @Environment(\.tunerController) private var tuner
    @ObservedObject private var monitor = AudioInputDeviceMonitor.shared

    private var devices: [AudioInputDevice] { monitor.devices }

    private var defaultDeviceName: String? {
        if let uid = monitor.defaultDeviceUID,
           let device = monitor.devices.first(where: { $0.id == uid }) {
            return device.name
        }
        return monitor.devices.first(where: \.isDefault)?.name
    }

    private var missingPreferredDevice: Bool {
        guard let preferred = settings.preferredInputDeviceUID else { return false }
        return !monitor.devices.contains { $0.id == preferred }
    }

    var body: some View {
        ZStack {
            AppBackground()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    descriptionCard
                    deviceList
                    hint
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 30)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(L10n.tr("输入设备"))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    monitor.refresh()
                } label: {
                    Label(L10n.tr("刷新"), systemImage: "arrow.clockwise")
                }
                .contentShape(Rectangle())
            }
        }
        .onAppear {
            monitor.start()
            monitor.refresh()
        }
    }

    // MARK: - 说明

    private var descriptionCard: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "mic.fill")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(AppTheme.success)
                .frame(width: 34, height: 34)
                .background(AppTheme.success.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(L10n.tr("选择麦克风或音频接口"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppTheme.primaryText)

                Text(L10n.tr("推荐使用内置麦克风或通过 USB 连接的音频接口。切换设备时会自动重新启动调音检测。"))
                    .font(.system(size: 12))
                    .foregroundStyle(AppTheme.secondaryText)
                    .lineSpacing(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .tunerCard(padding: 16)
    }

    // MARK: - 设备列表

    private var deviceList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("可用输入"))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppTheme.secondaryText)
                .padding(.leading, 4)

            VStack(spacing: 0) {
                systemDefaultRow
                ForEach(devices) { device in
                    Divider()
                        .overlay(AppTheme.divider)
                        .padding(.leading, 57)
                    deviceRow(device)
                }
            }
            .background(GlassCardBackground(cornerRadius: 18))
        }
    }

    private var systemDefaultRow: some View {
        Button {
            select(nil)
        } label: {
            deviceRowContent(
                icon: "gearshape.fill",
                tint: AppTheme.secondaryText,
                title: L10n.tr("系统默认"),
                subtitle: defaultDeviceName.map { L10n.tr("当前：%@", $0) } ?? L10n.tr("跟随 macOS 声音设置"),
                isSelected: settings.preferredInputDeviceUID == nil
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func deviceRow(_ device: AudioInputDevice) -> some View {
        Button {
            select(device.id)
        } label: {
            deviceRowContent(
                icon: device.isDefault ? "mic.fill" : "mic",
                tint: device.isDefault ? AppTheme.accent : AppTheme.secondaryText,
                title: device.name,
                subtitle: subtitle(for: device),
                isSelected: settings.preferredInputDeviceUID == device.id
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }

    private func deviceRowContent(icon: String,
                                  tint: Color,
                                  title: String,
                                  subtitle: String?,
                                  isSelected: Bool) -> some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(tint.opacity(0.13))

                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(tint)
            }
            .frame(width: 30, height: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppTheme.primaryText)
                    .lineLimit(1)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.secondaryText)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 8)

            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(isSelected ? AppTheme.accent : AppTheme.tertiaryText.opacity(0.5))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
        .contentShape(Rectangle())
    }

    private func subtitle(for device: AudioInputDevice) -> String? {
        var parts: [String] = []
        if device.isDefault {
            parts.append(L10n.tr("系统默认输入"))
        }
        if let kind = device.kindLabel {
            parts.append(kind)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    // MARK: - 提示

    @ViewBuilder
    private var hint: some View {
        VStack(alignment: .leading, spacing: 8) {
            if missingPreferredDevice {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.warning)

                    Text(L10n.tr("之前选择的输入设备当前不可用，请重新选择。"))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.warning.opacity(0.1))
                )
            }

            if !monitor.recentlyAdded.isEmpty {
                HStack(alignment: .top, spacing: 9) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(AppTheme.success)

                    Text(L10n.tr("已检测到新输入设备：%@",
                                 monitor.recentlyAdded.map(\.name).joined(separator: ", ")))
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(AppTheme.success.opacity(0.1))
                )
            }

            if missingPreferredDevice || monitor.recentlyAdded.isEmpty {
                Text(L10n.tr("设备增删或系统默认输入变化会自动更新，也可以点按右上角手动刷新。"))
                    .font(.system(size: 11))
                    .foregroundStyle(AppTheme.tertiaryText)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 2)
            }
        }
    }

    // MARK: - 操作

    private func select(_ uid: String?) {
        settings.preferredInputDeviceUID = uid
        if let tuner {
            settings.apply(to: tuner)
        }
    }
}
#endif
