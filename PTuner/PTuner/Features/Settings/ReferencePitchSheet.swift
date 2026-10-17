import SwiftUI

/// 自定义 A4 参考音高。
struct ReferencePitchSheet: View {
    @Environment(\.dismiss) private var dismiss

    let currentPitch: Double
    let onSave: (Double) -> Void

    @State private var text: String
    @State private var errorText: String?

    init(currentPitch: Double, onSave: @escaping (Double) -> Void) {
        self.currentPitch = currentPitch
        self.onSave = onSave
        _text = State(initialValue: Self.formatted(currentPitch))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppTheme.background.ignoresSafeArea()

                VStack(alignment: .leading, spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("A4 参考频率")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(AppTheme.secondaryText)

                        HStack(spacing: 10) {
                            TextField("440.0", text: $text)
                                .textFieldStyle(.plain)
                                .font(.system(size: 26, weight: .semibold, design: .rounded))
                                .foregroundStyle(AppTheme.primaryText)
                                .monospacedDigit()
                                .padding(.horizontal, 14)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .fill(AppTheme.surface)
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                                )
                                #if os(iOS)
                                .keyboardType(.decimalPad)
                                #endif

                            Text("Hz")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(AppTheme.secondaryText)
                        }
                    }

                    Text("允许范围 \(Int(TunerSettings.minimumReferencePitch))–\(Int(TunerSettings.maximumReferencePitch)) Hz。参考音高会影响所有调音模式。")
                        .font(.system(size: 12))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .fixedSize(horizontal: false, vertical: true)

                    if let errorText {
                        Text(errorText)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppTheme.danger)
                    }

                    Spacer()

                    PrimaryTunerButton(title: "应用", systemImage: "checkmark") {
                        apply()
                    }

                    PrimaryTunerButton(title: "恢复 440 Hz", systemImage: "arrow.counterclockwise", role: .secondary) {
                        onSave(440)
                        dismiss()
                    }
                }
                .padding(20)
                .frame(maxWidth: 460)
                .frame(maxWidth: .infinity)
            }
            .navigationTitle("自定义参考音高")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                        .contentShape(Rectangle())
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func apply() {
        let normalized = text
            .replacingOccurrences(of: "，", with: ".")
            .replacingOccurrences(of: ",", with: ".")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let value = Double(normalized) else {
            errorText = "请输入有效的数字。"
            return
        }
        guard (TunerSettings.minimumReferencePitch...TunerSettings.maximumReferencePitch).contains(value) else {
            errorText = "参考音高需要在 400–480 Hz 之间。"
            return
        }

        onSave(value)
        dismiss()
    }

    private static func formatted(_ value: Double) -> String {
        let rounded = (value * 10).rounded() / 10
        if rounded == rounded.rounded() {
            return String(format: "%.0f", rounded)
        }
        return String(format: "%.1f", rounded)
    }
}
