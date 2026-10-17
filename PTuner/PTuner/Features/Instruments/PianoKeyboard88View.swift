import SwiftUI

/// 88 键钢琴音高对照图（A0–C8）。
/// 用于说明音名后的八度数字，并高亮当前调弦包含的音。
struct PianoKeyboard88View: View {
    let highlightedNotes: Set<Int>

    private let firstMIDI = 21
    private let lastMIDI = 108
    private let labelHeight: CGFloat = 18

    private static let whitePitchClasses: Set<Int> = [0, 2, 4, 5, 7, 9, 11]
    private static let blackPitchClasses: Set<Int> = [1, 3, 6, 8, 10]

    private var whiteNotes: [Int] {
        (firstMIDI...lastMIDI).filter { Self.whitePitchClasses.contains($0 % 12) }
    }

    /// 黑键连同它左侧白键的数量，用于按白键边界定位。
    private var blackKeys: [(midi: Int, whiteKeysBefore: Int)] {
        let whites = whiteNotes
        return (firstMIDI...lastMIDI).compactMap { midi in
            guard Self.blackPitchClasses.contains(midi % 12) else { return nil }
            return (midi, whites.filter { $0 < midi }.count)
        }
    }

    /// 每个 C 及其八度数字；另外标出最低的 A0。
    private var octaveLabels: [(id: Int, text: String, whiteIndex: Int)] {
        let whites = whiteNotes
        var labels = [(id: Int, text: String, whiteIndex: Int)]()
        if let first = whites.first {
            labels.append((first, "A0", 0))
        }
        for midi in whites where midi % 12 == 0 {
            guard let index = whites.firstIndex(of: midi) else { continue }
            labels.append((midi, "C\(midi / 12 - 1)", index))
        }
        return labels
    }

    var body: some View {
        GeometryReader { proxy in
            let keyboardHeight = max(0, proxy.size.height - labelHeight)
            let whiteWidth = proxy.size.width / CGFloat(whiteNotes.count)
            let blackWidth = whiteWidth * 0.62
            let blackHeight = keyboardHeight * 0.62

            ZStack(alignment: .topLeading) {
                ForEach(Array(whiteNotes.enumerated()), id: \.offset) { index, midi in
                    RoundedRectangle(cornerRadius: 2, style: .continuous)
                        .fill(highlightedNotes.contains(midi) ? AppTheme.accent : whiteKeyColor)
                        .overlay(
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .stroke(keyBorder, lineWidth: 0.5)
                        )
                        .frame(width: whiteWidth, height: keyboardHeight)
                        .offset(x: CGFloat(index) * whiteWidth)
                }

                ForEach(Array(blackKeys.enumerated()), id: \.offset) { _, key in
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(highlightedNotes.contains(key.midi) ? AppTheme.accent : blackKeyColor)
                        .frame(width: blackWidth, height: blackHeight)
                        .offset(x: CGFloat(key.whiteKeysBefore) * whiteWidth - blackWidth / 2)
                }

                ForEach(octaveLabels, id: \.id) { label in
                    Text(label.text)
                        .font(.system(size: 8, weight: .medium, design: .rounded))
                        .foregroundStyle(AppTheme.tertiaryText)
                        .position(x: (CGFloat(label.whiteIndex) + 0.5) * whiteWidth,
                                  y: keyboardHeight + labelHeight / 2)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(L10n.tr("88 键钢琴音高对照图，从 A0 到 C8"))
    }

    private var whiteKeyColor: Color {
        Color(light: 0xFFFFFF, dark: 0xE7EBF1)
    }

    private var blackKeyColor: Color {
        Color(light: 0x1F2937, dark: 0x0B0F14)
    }

    private var keyBorder: Color {
        Color(light: 0x000000, dark: 0xFFFFFF).opacity(0.14)
    }
}
