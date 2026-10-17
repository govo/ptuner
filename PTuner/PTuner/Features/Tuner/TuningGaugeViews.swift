import SwiftUI

/// 半圆指针表：弧形刻度带冷蓝 → 绿 → 橙的渐变光晕，指针是一根发光光条。
///
/// 刻度并非等分：两端（-50 ~ -20、+20 ~ +50）被压缩，中间 ±20 音分占据主要视野，
/// 和参考图里专业调音表的刻度分布一致。
struct NeedleGaugeView: View {
    /// 与主页读数区组合时使用的固定高度。
    static let preferredHeight: CGFloat = 210

    /// -50 ~ +50 音分；nil 表示当前没有读数。
    let cents: Double?
    let status: TuningStatus

    /// (音分值, 在弧上的归一化位置)。
    private static let scale: [(cents: Double, position: Double)] = [
        (-50, 0.00), (-20, 0.30), (-10, 0.40), (0, 0.50),
        (10, 0.60), (20, 0.70), (50, 1.00)
    ]

    private var position: Double {
        guard let cents else { return 0.5 }
        return Self.position(for: cents)
    }

    /// 把音分值映射到刻度位置，供指针和绿色合格区共用。
    private static func position(for cents: Double) -> Double {
        let value = max(-50, min(50, cents))
        let scale = Self.scale

        for index in 0..<(scale.count - 1) {
            let lower = scale[index]
            let upper = scale[index + 1]
            guard value <= upper.cents else { continue }
            let span = upper.cents - lower.cents
            let progress = span == 0 ? 0 : (value - lower.cents) / span
            return lower.position + (upper.position - lower.position) * progress
        }
        return 1
    }

    private var needleColor: Color {
        cents == nil ? Color.white.opacity(0.26) : status.color
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let center = CGPoint(x: width / 2, y: height - 10)
            let radius = min(width / 2 - 30, height - 54)

            ZStack {
                // 外层光晕：让整条弧像有光源。
                arcPath(center: center, radius: radius)
                    .stroke(AppTheme.gaugeLinear,
                            style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .blur(radius: 9)
                    .opacity(0.5)

                // 弧线本体。
                arcPath(center: center, radius: radius)
                    .stroke(AppTheme.gaugeLinear,
                            style: StrokeStyle(lineWidth: 3.2, lineCap: .round))

                // 中心合格区：±5 音分内的一段加粗绿弧，明确告诉用户「落在这里就准了」。
                acceptableZone(center: center, radius: radius)

                // 刻度线：细密，颜色跟随所在位置的弧色。
                ticks(center: center, radius: radius)
                    .opacity(0.75)

                scaleLabels(center: center, radius: radius)

                needle(center: center, radius: radius)
            }
        }
        .frame(height: Self.preferredHeight)
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: position)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - 几何

    private func point(center: CGPoint, radius: Double, normalized: Double) -> CGPoint {
        let theta = Double.pi - normalized * Double.pi
        return CGPoint(
            x: center.x + cos(theta) * radius,
            y: center.y - sin(theta) * radius
        )
    }

    private func arcPath(center: CGPoint, radius: Double) -> Path {
        arcPath(center: center, radius: radius, from: 0, to: 1)
    }

    private func arcPath(center: CGPoint,
                         radius: Double,
                         from: Double,
                         to: Double) -> Path {
        Path { path in
            let steps = 96
            path.move(to: point(center: center, radius: radius, normalized: from))
            for index in 1...steps {
                let progress = from + (to - from) * Double(index) / Double(steps)
                path.addLine(to: point(center: center,
                                       radius: radius,
                                       normalized: progress))
            }
        }
    }

    /// 中心合格区：外发光 + 加粗绿弧。
    private func acceptableZone(center: CGPoint, radius: Double) -> some View {
        let from = Self.position(for: -5)
        let to = Self.position(for: 5)
        let path = arcPath(center: center, radius: radius, from: from, to: to)

        return ZStack {
            path.stroke(AppTheme.gaugeGreen.opacity(0.55),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round))
                .blur(radius: 6)

            path.stroke(AppTheme.gaugeGreen,
                        style: StrokeStyle(lineWidth: 6.5, lineCap: .round))
        }
        .animation(.spring(response: 0.24, dampingFraction: 0.72), value: cents)
    }

    // MARK: - 刻度

    private func ticks(center: CGPoint, radius: Double) -> some View {
        ZStack {
            tickPath(center: center, radius: radius, isMajor: false)
                .stroke(AppTheme.gaugeLinear, lineWidth: 1)

            tickPath(center: center, radius: radius, isMajor: true)
                .stroke(AppTheme.gaugeLinear, lineWidth: 1.6)
        }
    }

    private func tickPath(center: CGPoint, radius: Double, isMajor: Bool) -> Path {
        Path { path in
            // 每隔 2.5% 一根细刻度，每 5 根加长一根。
            for index in 0...80 {
                let isMajorTick = index % 5 == 0
                guard isMajorTick == isMajor else { continue }

                let normalized = Double(index) / 80.0
                let length: Double = isMajor ? 13 : 6
                let inner = point(center: center,
                                  radius: radius - length,
                                  normalized: normalized)
                let outer = point(center: center,
                                  radius: radius - 2,
                                  normalized: normalized)
                path.move(to: inner)
                path.addLine(to: outer)
            }
        }
    }

    private func scaleLabels(center: CGPoint, radius: Double) -> some View {
        ForEach(Array(Self.scale.enumerated()), id: \.offset) { _, item in
            let anchor = point(center: center,
                               radius: radius + 17,
                               normalized: item.position)
            Text(labelText(item.cents))
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(item.cents == 0
                                 ? AppTheme.primaryText.opacity(0.85)
                                 : AppTheme.tertiaryText)
                .position(anchor)
        }
    }

    private func labelText(_ cents: Double) -> String {
        if cents > 0 { return "+\(Int(cents))" }
        return "\(Int(cents))"
    }

    // MARK: - 指针

    private func needle(center: CGPoint, radius: Double) -> some View {
        // 指针要停在音名上方，长度控制在半径的约四分之一。
        let length = min(44, radius * 0.23)
        let outer = point(center: center, radius: radius - 4, normalized: position)
        let inner = point(center: center, radius: radius - length, normalized: position)
        let color = needleColor

        let path = Path { path in
            path.move(to: inner)
            path.addLine(to: outer)
        }

        return ZStack {
            path.stroke(color.opacity(0.55),
                        style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .blur(radius: 7)

            path.stroke(color,
                        style: StrokeStyle(lineWidth: 3, lineCap: .round))

            path.stroke(Color.white.opacity(0.7),
                        style: StrokeStyle(lineWidth: 1, lineCap: .round))
        }
    }

    private var accessibilityText: String {
        guard let cents else { return L10n.tr("等待声音") }
        return L10n.tr("音准偏差 %d 音分，%@", Int(cents.rounded()), status.directionText)
    }
}

/// 横向音准条样式：渐变刻度轨道 + 发光游标。
struct HorizontalGaugeView: View {
    let cents: Double?
    let status: TuningStatus

    var body: some View {
        VStack(spacing: 8) {
            GeometryReader { geo in
                let width = geo.size.width
                let ratio = max(-1.0, min(1.0, (cents ?? 0) / 50.0))
                let centerX = width / 2
                let positionX = centerX + ratio * (width / 2 - 8)
                let fill = abs(positionX - centerX)
                let color = cents == nil ? Color.white.opacity(0.25) : status.color

                ZStack {
                    // 底色轨道。
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 4)

                    // 渐变刻度线：两端冷蓝 / 暖橙，中心绿色。
                    Capsule()
                        .fill(AppTheme.gaugeLinear)
                        .frame(height: 3)
                        .opacity(0.55)
                        .blur(radius: 3)

                    // 从中心到当前偏差的发光填充。
                    Capsule()
                        .fill(color)
                        .frame(width: max(2, fill), height: 3)
                        .position(x: centerX + (ratio >= 0 ? fill / 2 : -fill / 2),
                                  y: geo.size.height / 2)
                        .shadow(color: color.opacity(0.7), radius: 5)

                    // 中心刻度。
                    Capsule()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 1.5, height: 14)
                        .position(x: centerX, y: geo.size.height / 2)

                    // 发光游标。
                    Circle()
                        .fill(color)
                        .frame(width: 11, height: 11)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.65), lineWidth: 1)
                        )
                        .shadow(color: color.opacity(0.9), radius: 7)
                        .position(x: positionX, y: geo.size.height / 2)
                }
            }
            .frame(height: 22)

            HStack(spacing: 0) {
                Text("-50")
                Spacer()
                Text("0")
                Spacer()
                Text("+50")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(AppTheme.tertiaryText)
            .padding(.horizontal, 2)
        }
        .frame(height: 52)
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: cents)
    }
}

/// 卡片内的竖向音准指示器：中心 0，偏高在上、偏低在下。
/// 与横向 CentsBar 不同，它用于纵向排列的整琴校验卡片。
struct VerticalCentsIndicator: View {
    /// nil 表示待检测。
    let cents: Double?
    let status: TuningStatus
    var height: CGFloat = 76
    var showsScaleLabels: Bool = false

    /// +1 = 顶端（+50 cents），-1 = 底端（-50 cents）。
    private var ratio: Double {
        guard let cents else { return 0 }
        return max(-1.0, min(1.0, cents / 50.0))
    }

    var body: some View {
        HStack(spacing: 5) {
            GeometryReader { geo in
                let trackWidth: CGFloat = 5
                let usableHeight = max(1, geo.size.height - 10)
                let offset = CGFloat(ratio) * usableHeight / 2
                let fillHeight = max(2, abs(offset))
                let color = cents == nil ? Color.white.opacity(0.22) : status.color

                ZStack {
                    Capsule()
                        .fill(Color.white.opacity(0.07))
                        .frame(width: trackWidth, height: geo.size.height)

                    ForEach([-50.0, -25.0, 0.0, 25.0, 50.0], id: \.self) { mark in
                        Rectangle()
                            .fill(mark == 0
                                  ? AppTheme.primaryText.opacity(0.5)
                                  : AppTheme.tertiaryText.opacity(0.3))
                            .frame(width: mark == 0 ? 18 : 12, height: mark == 0 ? 1.5 : 1)
                            .offset(y: CGFloat(-mark / 50.0) * usableHeight / 2)
                    }

                    if cents != nil {
                        if abs(ratio) > 0.0001 {
                            Capsule()
                                .fill(color)
                                .frame(width: trackWidth, height: fillHeight)
                                .offset(y: ratio >= 0 ? -fillHeight / 2 : fillHeight / 2)
                                .shadow(color: color.opacity(0.6), radius: 4)
                        }

                        // 即使音分正好为 0 也要显示指针，让「准」有明确的绿色反馈。
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(color)
                            .frame(width: 20, height: 3)
                            .offset(y: -offset)
                            .shadow(color: color.opacity(0.85), radius: 5)
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 4, height: 4)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(width: 20, height: height)

            if showsScaleLabels {
                VStack(spacing: 0) {
                    Text("+50")
                    Spacer()
                    Text("0")
                    Spacer()
                    Text("-50")
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(AppTheme.tertiaryText)
                .frame(height: height)
            }
        }
        .animation(.spring(response: 0.22, dampingFraction: 0.75), value: cents)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let cents else { return L10n.tr("待检测") }
        if status == .inTune { return L10n.tr("音准准确") }
        return L10n.tr("%@ %d 音分", status.directionText, Int(abs(cents).rounded()))
    }
}
