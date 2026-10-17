//
//  CrepePitchDecoder.swift
//  PTuner
//
//  逐帧激活 -> 连续音高（marl/crepe 的 local average 解码）。
//

import Foundation

nonisolated struct CrepeFramePitch {
    /// 连续 MIDI 音高。
    let midi: Double
    /// 该帧的置信度（激活最大值）。
    let confidence: Float
}

nonisolated enum CrepePitchDecoder {

    /// 一帧的解码结果：加权平均音分 + 置信度。
    static func localAverageCents(activations: [Float], base: Int) -> (cents: Double, confidence: Float) {
        let bins = CrepeConstants.pitchBins
        let radius = CrepeConstants.localAverageRadius

        var center = 0
        var best = activations[base]
        for bin in 1..<bins where activations[base + bin] > best {
            best = activations[base + bin]
            center = bin
        }

        let start = max(0, center - radius)
        let end = min(bins, center + radius + 1)
        var productSum = 0.0
        var weightSum = 0.0
        for bin in start..<end {
            let weight = Double(activations[base + bin])
            productSum += weight * (CrepeConstants.centsOffset + CrepeConstants.centsPerBin * Double(bin))
            weightSum += weight
        }
        let fallback = CrepeConstants.centsOffset + CrepeConstants.centsPerBin * Double(center)
        return (weightSum > 0 ? productSum / weightSum : fallback, best)
    }

    /// 逐帧解码整段激活矩阵。
    static func decode(activations: [Float], frameCount: Int) -> [CrepeFramePitch] {
        let bins = CrepeConstants.pitchBins
        var result: [CrepeFramePitch] = []
        result.reserveCapacity(frameCount)
        for frame in 0..<frameCount {
            let decoded = localAverageCents(activations: activations, base: frame * bins)
            result.append(CrepeFramePitch(midi: CrepeConstants.centsToMidi(decoded.cents),
                                          confidence: decoded.confidence))
        }
        return result
    }
}
