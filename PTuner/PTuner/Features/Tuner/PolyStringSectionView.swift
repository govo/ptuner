import SwiftUI

/// 多音调音表：以选定乐器的全部目标弦为主角。
/// 每根弦一列，竖向 -50 ~ +50 音分表在上，原来的弦位元素（音名 + 弦号圆点）在下。
struct MultiStringTuningStrip: View {
    /// 当前只拨响一根弦时，用单音 CREPE 的实时读数覆盖这根弦，
    /// 让它拥有和单音模式一样快的指针响应；其余弦仍用多音通道。
    struct LiveCents: Equatable {
        let stringIndex: Int
        let cents: Double
    }

    let resolved: [PolyStringVerificationStore.ResolvedSlot]
    let centsPrecision: CentsPrecision
    var liveCents: LiveCents?
    /// 点击某根弦时播放它的目标音高。
    let onPlayTone: (Double) -> Void

    /// 超过这个弦数才改用网格换行，普通吉他、贝斯等保持一排。
    private let singleRowMaxStrings = 8

    var body: some View {
        Group {
            if resolved.count <= singleRowMaxStrings {
                HStack(alignment: .bottom, spacing: 4) {
                    columns
                }
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 48, maximum: 84), spacing: 10)],
                          spacing: 14) {
                    columns
                }
            }
        }
        .frame(maxWidth: .infinity)
        .tunerCard(padding: 18)
    }

    private var columns: some View {
        ForEach(resolved) { item in
            MultiStringColumn(slot: item.slot,
                              isRetained: item.isRetained,
                              centsPrecision: centsPrecision,
                              liveCents: liveCents,
                              onPlayTone: onPlayTone)
        }
    }
}

/// 单根弦的一列：竖表 + 弦名 + 弦号圆点。
/// 弦名与圆点沿用单音页面 `stringChips` 的尺寸和样式，不做放大。
private struct MultiStringColumn: View {
    let slot: PolyStringSlot
    let isRetained: Bool
    let centsPrecision: CentsPrecision
    let liveCents: MultiStringTuningStrip.LiveCents?
    let onPlayTone: (Double) -> Void

    /// 单音通道覆盖值优先；否则用多音通道的读数。
    private var displayCents: Double? {
        if let liveCents, liveCents.stringIndex == slot.stringIndex {
            return liveCents.cents
        }
        return slot.cents
    }

    private var status: TuningStatus {
        guard let cents = displayCents else { return .idle }
        return TuningStatus.from(cents: cents)
    }

    private var isDetected: Bool { displayCents != nil }

    private var isLive: Bool {
        liveCents?.stringIndex == slot.stringIndex
    }

    private var statusColor: Color {
        isDetected ? status.color : AppTheme.tertiaryText
    }

    private var centsLabel: String {
        guard let cents = displayCents else { return "—" }
        return centsPrecision.format(cents)
    }

    var body: some View {
        Button {
            onPlayTone(slot.targetFrequency)
        } label: {
            VStack(spacing: 4) {
                Text("+50")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.tertiaryText)

                VerticalCentsIndicator(cents: displayCents,
                                       status: status,
                                       height: 84)

                Text("-50")
                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                    .foregroundStyle(AppTheme.tertiaryText)

                Text(slot.targetNoteName)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(isDetected ? AppTheme.accent : AppTheme.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.top, 2)

                Text(centsLabel)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(isDetected ? statusColor : AppTheme.tertiaryText)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                ZStack {
                    Circle()
                        .fill(isDetected ? statusColor.opacity(0.14) : AppTheme.controlBackground)

                    Circle()
                        .stroke(isDetected ? statusColor.opacity(0.7) : AppTheme.cardBorder,
                                lineWidth: 1)

                    if isDetected {
                        Image(systemName: status.symbolName)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(statusColor)
                    } else {
                        Text("\(slot.stringNumber)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(AppTheme.tertiaryText)
                    }
                }
                .frame(width: 30, height: 30)
            }
            .frame(maxWidth: .infinity)
            .opacity(isLive ? 1 : (isRetained ? 0.82 : 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityText)
        .accessibilityHint("播放该弦参考音")
    }

    private var accessibilityText: String {
        let target = "\(slot.stringNumber)弦，\(slot.targetNoteName)"
        guard let cents = displayCents else { return "\(target)，待检测" }
        let value = String(format: "%.\(centsPrecision.digits)f", abs(cents))
        return "\(target)，\(status.directionText) \(value) 音分"
    }
}
