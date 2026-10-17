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
