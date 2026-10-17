//
//  CrepeConstants.swift
//  PTuner
//
//  CREPE（单声部音高追踪）的常数与换算，取自 torchcrepe 0.0.24 / marl/crepe。
//  数值全部保真上游，不做本地调优，以便与官方实现逐项对照。
//

import Foundation

nonisolated enum CrepeConstants {

    // MARK: - 音频

    static let sampleRate = 16000
    /// 每窗采样点数（64 ms）。
    static let windowSize = 1024
    /// 相邻帧起点的间隔（10 ms）。
    static let hopLength = 160
    /// 帧率：16000 / 160 = 100。
    static var framesPerSecond: Double { Double(sampleRate) / Double(hopLength) }
    /// 音频两端各补的零采样数。
    static let padLength = windowSize / 2

    // MARK: - 音高网格

    /// 音高 bin 数。
    static let pitchBins = 360
    /// 每个 bin 覆盖的音分数。
    static let centsPerBin = 20.0
    /// 第 0 个 bin 的音分下界。
    static let centsOffset = 1997.3794084376191
    /// 覆盖频率 31.70 ~ 2006.00 Hz。

    // MARK: - 解码

    /// local average 解码：在 argmax 两侧各取 4 个 bin（共最多 9 个）做加权平均。
    static let localAverageRadius = 4

    // MARK: - 后处理

    /// 置信度阈值：低于此值的帧判为未发声（起音）。
    static let defaultConfidenceThreshold: Float = 0.5
    /// 滞回宽度：已经在发声的音符，置信度要跌破 阈值 - 此值 才算结束。
    static let hysteresisMargin: Float = 0.1
    /// 音符最短时长。短于此的同音高碎片会被丢弃。
    static let minNoteSeconds: Double = 0.06
    /// 丢弃碎片后，同音高、间隔不超过此值的两段重新并成一个音符。
    static let mergeGapSeconds: Double = 0.05

    /// 单次处理的最长音频（秒）。
    static let maxProcessSeconds: Double = 300
    /// 每次推理送入模型的帧数。模型 batch 维是可变长度（1 ~ 1024）。
    static let batchSize = 128

    // MARK: - 模型接口名（转换脚本里指定）

    static let modelName = "Crepe"
    static let inputName = "frames"
    static let outputName = "activations"

    // MARK: - 音高换算

    /// 音分 → 频率（Hz）：f = 10 * 2 ** (cents / 1200)。
    static func centsToFrequency(_ cents: Double) -> Double {
        10.0 * pow(2.0, cents / 1200.0)
    }

    /// 频率（Hz）→ 连续 MIDI 音高。
    static func frequencyToMidi(_ hertz: Double) -> Double {
        guard hertz > 0 else { return .nan }
        return 69.0 + 12.0 * log2(hertz / 440.0)
    }

    /// 音分 → 连续 MIDI 音高。
    static func centsToMidi(_ cents: Double) -> Double {
        frequencyToMidi(centsToFrequency(cents))
    }

    /// 第 index 个 bin 的下边缘对应的连续 MIDI 音高（index 可为小数）。
    static func binEdgeMidi(_ index: Double) -> Double {
        centsToMidi(centsOffset + centsPerBin * index)
    }

    /// 热力图每一行覆盖的 MIDI 区间：首尾各外扩半个 bin。
    static var heatmapMidiRange: ClosedRange<Double> {
        let low = binEdgeMidi(-0.5)
        let high = binEdgeMidi(Double(pitchBins) - 0.5)
        return low...high
    }
}
