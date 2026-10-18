import AVFoundation
import Combine
import Foundation

/// 参考音波形。方波谐波更丰富，听感更明显，作为默认值。
nonisolated enum ReferenceToneWaveform: String, CaseIterable, Identifiable, Sendable {
    case square
    case sine

    var id: String { rawValue }

    var title: String {
        switch self {
        case .square: return L10n.tr("方波")
        case .sine: return L10n.tr("正弦波")
        }
    }
}

/// 参考音播放器：用指定波形播放音高，供点击弦位时试听目标音高。
/// 每次播放都会打断上一段，播放固定时长后自然结束。
@MainActor
final class TonePlayer: ObservableObject {

    /// 播放时长（秒）。
    private let duration: TimeInterval = 2.0
    /// 输出音量，避免参考音过响盖过真实琴声。
    private let volume: Float = 0.3

    private var player: AVAudioPlayer?

    func play(frequency: Double, waveform: ReferenceToneWaveform = .square) {
        guard frequency.isFinite, frequency > 0,
              let data = Self.makeWave(frequency: frequency,
                                       duration: duration,
                                       waveform: waveform) else { return }

        player?.stop()

        do {
            let player = try AVAudioPlayer(data: data)
            player.volume = volume
            player.prepareToPlay()
            player.play()
            self.player = player
        } catch {
            player = nil
        }
    }

    func stop() {
        player?.stop()
        player = nil
    }

    // MARK: - 波形生成

    /// 生成一段 16-bit 单声道 WAV 数据。
    /// 首尾加入淡入淡出，避免起止时的爆音。
    private static func makeWave(frequency: Double,
                                 duration: TimeInterval,
                                 waveform: ReferenceToneWaveform) -> Data? {
        let sampleRate = 44_100.0
        let frameCount = Int(sampleRate * duration)
        guard frameCount > 0 else { return nil }

        let attackFrames = max(1, Int(sampleRate * 0.015))
        let releaseFrames = max(1, min(frameCount / 2, Int(sampleRate * 0.15)))
        // 方波的感知响度明显高于正弦波，用更低振幅避免刺耳与削波。
        let amplitude = waveform == .square ? 0.55 : 0.95

        var samples = [Int16](repeating: 0, count: frameCount)
        for index in 0..<frameCount {
            let phase = 2.0 * Double.pi * frequency * Double(index) / sampleRate
            var gain = 1.0
            if index < attackFrames {
                gain = Double(index) / Double(attackFrames)
            }
            let remaining = frameCount - index
            if remaining < releaseFrames {
                gain = min(gain, Double(remaining) / Double(releaseFrames))
            }

            let sample: Double
            switch waveform {
            case .sine:
                sample = sin(phase)
            case .square:
                sample = sin(phase) >= 0 ? 1.0 : -1.0
            }

            let value = sample * amplitude * gain * Double(Int16.max)
            samples[index] = Int16(clamping: Int(value.rounded()))
        }

        return makeWAV(samples: samples, sampleRate: Int(sampleRate))
    }

    private static func makeWAV(samples: [Int16], sampleRate: Int) -> Data {
        let channels: UInt16 = 1
        let bitsPerSample: UInt16 = 16
        let blockAlign = channels * bitsPerSample / 8
        let byteRate = UInt32(sampleRate) * UInt32(blockAlign)
        let dataSize = UInt32(samples.count * 2)

        var data = Data(capacity: 44 + samples.count * 2)

        func append(_ value: UInt32) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }

        func append(_ value: UInt16) {
            var littleEndian = value.littleEndian
            withUnsafeBytes(of: &littleEndian) { data.append(contentsOf: $0) }
        }

        data.append(contentsOf: Array("RIFF".utf8))
        append(36 + dataSize)
        data.append(contentsOf: Array("WAVE".utf8))

        data.append(contentsOf: Array("fmt ".utf8))
        append(UInt32(16))
        append(UInt16(1))
        append(channels)
        append(UInt32(sampleRate))
        append(byteRate)
        append(blockAlign)
        append(bitsPerSample)

        data.append(contentsOf: Array("data".utf8))
        append(dataSize)
        for sample in samples {
            append(UInt16(bitPattern: sample))
        }

        return data
    }
}
