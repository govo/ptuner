import SwiftUI

/// 专业调音单块风格的半圆指针表。
struct NeedleGaugeView: View {
    /// -50 ~ +50 音分；nil 表示当前没有读数。
    let cents: Double?
    let status: TuningStatus

    private var normalized: Double {
        guard let cents else { return 0.5 }
        return 0.5 + max(-50, min(50, cents)) / 100.0
    }

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let center = CGPoint(x: width / 2, y: height - 8)
            let radius = min(width / 2 - 16, height - 30)

            ZStack {
                arcPath(center: center, radius: radius)
                    .stroke(AppTheme.gaugeTrack, style: StrokeStyle(lineWidth: 3, lineCap: .round))

                arcPath(center: center, radius: radius, from: 0.44, to: 0.56)
                    .stroke(AppTheme.success.opacity(0.85), style: StrokeStyle(lineWidth: 4, lineCap: .round))

                ticks(center: center, radius: radius)

                scaleLabel("-50", center: center, radius: radius, normalized: 0.0)
                scaleLabel("0", center: center, radius: radius, normalized: 0.5)
                scaleLabel("+50", center: center, radius: radius, normalized: 1.0)

                needle(center: center, radius: radius)
            }
        }
        .frame(height: 150)
        .animation(.linear(duration: 0.08), value: normalized)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private func point(center: CGPoint, radius: Double, normalized: Double) -> CGPoint {
        let theta = Double.pi - normalized * Double.pi
        return CGPoint(
            x: center.x + cos(theta) * radius,
            y: center.y - sin(theta) * radius
        )
    }

    private func arcPath(center: CGPoint,
                         radius: Double,
                         from: Double = 0,
                         to: Double = 1) -> Path {
        Path { path in
            let steps = 80
            path.move(to: point(center: center, radius: radius, normalized: from))
            for index in 1...steps {
                let value = from + (to - from) * Double(index) / Double(steps)
                path.addLine(to: point(center: center, radius: radius, normalized: value))
            }
        }
    }

    private func ticks(center: CGPoint, radius: Double) -> some View {
        ZStack {
            ForEach(Array(0...10), id: \.self) { index in
                let normalized = Double(index) / 10.0
                let isCenter = index == 5
                let inner = point(center: center,
                                  radius: radius - (isCenter ? 12 : 7),
                                  normalized: normalized)
                let outer = point(center: center, radius: radius, normalized: normalized)

                Path { path in
                    path.move(to: inner)
                    path.addLine(to: outer)
                }
                .stroke(isCenter ? AppTheme.primaryText.opacity(0.6) : AppTheme.secondaryText.opacity(0.35),
                        style: StrokeStyle(lineWidth: isCenter ? 2 : 1, lineCap: .round))
            }
        }
    }

    private func scaleLabel(_ text: String,
                            center: CGPoint,
                            radius: Double,
                            normalized: Double) -> some View {
        let anchor = point(center: center, radius: radius + 13, normalized: normalized)
        return Text(text)
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(AppTheme.tertiaryText)
            .position(anchor)
    }

    private func needle(center: CGPoint, radius: Double) -> some View {
        let tip = point(center: center, radius: radius - 18, normalized: normalized)
        let color = cents == nil ? AppTheme.tertiaryText.opacity(0.5) : status.color

        return ZStack {
            Path { path in
                path.move(to: center)
                path.addLine(to: tip)
            }
            .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .shadow(color: color.opacity(0.35), radius: 5)

            Circle()
                .fill(color)
                .frame(width: 9, height: 9)
                .position(center)
        }
    }

    private var accessibilityText: String {
        guard let cents else { return "等待声音" }
        return "音准偏差 \(Int(cents.rounded())) 音分，\(status.directionText)"
    }
}

/// 横向音准条样式。
struct HorizontalGaugeView: View {
    let cents: Double?
    let status: TuningStatus

    var body: some View {
        VStack(spacing: 7) {
            GeometryReader { geo in
                let width = geo.size.width
                let ratio = max(-1.0, min(1.0, (cents ?? 0) / 50.0))
                let fill = max(3, abs(ratio) * width / 2)
                let color = cents == nil ? AppTheme.tertiaryText.opacity(0.4) : status.color

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(AppTheme.gaugeTrack)
                        .frame(height: 12)

                    Capsule()
                        .fill(color)
                        .frame(width: fill, height: 12)
                        .offset(x: ratio >= 0 ? width / 2 : width / 2 - fill)

                    Rectangle()
                        .fill(AppTheme.primaryText.opacity(0.55))
                        .frame(width: 2, height: 22)
                        .offset(x: width / 2 - 1)

                    ForEach([-50, -25, 0, 25, 50], id: \.self) { mark in
                        Rectangle()
                            .fill(AppTheme.tertiaryText.opacity(0.35))
                            .frame(width: 1, height: 6)
                            .offset(x: width / 2 + CGFloat(mark) / 50.0 * width / 2 - 0.5,
                                    y: 10)
                    }
                }
            }
            .frame(height: 24)

            HStack {
                Text("-50")
                Spacer()
                Text("0")
                Spacer()
                Text("+50")
            }
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(AppTheme.tertiaryText)
        }
        .frame(height: 48)
        .animation(.linear(duration: 0.08), value: cents)
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
                let trackWidth: CGFloat = 6
                let usableHeight = max(1, geo.size.height - 10)
                let offset = CGFloat(ratio) * usableHeight / 2
                let fillHeight = max(2, abs(offset))
                let color = cents == nil ? AppTheme.tertiaryText.opacity(0.4) : status.color

                ZStack {
                    Capsule()
                        .fill(AppTheme.gaugeTrack)
                        .frame(width: trackWidth, height: geo.size.height)

                    ForEach([-50.0, -25.0, 0.0, 25.0, 50.0], id: \.self) { mark in
                        Rectangle()
                            .fill(mark == 0
                                  ? AppTheme.primaryText.opacity(0.55)
                                  : AppTheme.tertiaryText.opacity(0.35))
                            .frame(width: mark == 0 ? 18 : 12, height: mark == 0 ? 1.5 : 1)
                            .offset(y: CGFloat(-mark / 50.0) * usableHeight / 2)
                    }

                    if cents != nil {
                        if abs(ratio) > 0.0001 {
                            Capsule()
                                .fill(color)
                                .frame(width: trackWidth, height: fillHeight)
                                .offset(y: ratio >= 0 ? -fillHeight / 2 : fillHeight / 2)
                        }

                        // 即使音分正好为 0 也要显示指针，让「准」有明确的绿色反馈。
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(color)
                            .frame(width: 20, height: 3)
                            .offset(y: -offset)
                            .shadow(color: color.opacity(0.35), radius: 3)
                    } else {
                        Circle()
                            .fill(AppTheme.tertiaryText.opacity(0.6))
                            .frame(width: 5, height: 5)
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
        .animation(.linear(duration: 0.08), value: cents)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        guard let cents else { return "待检测" }
        if status == .inTune { return "音准准确" }
        return "\(status.directionText) \(Int(abs(cents).rounded())) 音分"
    }
}
