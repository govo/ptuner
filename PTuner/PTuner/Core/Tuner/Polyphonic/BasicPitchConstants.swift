//
//  BasicPitchConstants.swift
//  PTuner
//
//  Basic Pitch 的常量与后处理默认参数，移植自 basic_pitch/constants.py。
//  数值全部取自上游，不做本地调优，以保证与官方实现可以逐项对照。
//

import Foundation

nonisolated enum BasicPitchConstants {

    // MARK: - 音频

    static let sampleRate = 22050
    static let fftHop = 256

    // MARK: - 标注网格

    /// 每窗音频时长（秒）。
    static let audioWindowLength = 2
    /// 模型输入的采样点数：22050 * 2 - 256 = 43844。
    static let audioNSamples = sampleRate * audioWindowLength - fftHop
    /// 标注帧率：22050 / 256 = 86。
    static let annotationsFPS = sampleRate / fftHop
    /// 每窗输出的帧数：86 * 2 = 172。
    static let annotNFrames = annotationsFPS * audioWindowLength

    // MARK: - 音高网格

    /// 最低音 A0 的频率。
    static let baseFrequency: Double = 27.5
    /// 88 键钢琴。
    static let nSemitones = 88
    /// MIDI 21 = A0，对应 bin 0。
    static let midiOffset = 21
    /// contour 每半音 3 格。
    static let contoursBinsPerSemitone = 3
    static let nFreqBinsNotes = nSemitones
    static let nFreqBinsContours = nSemitones * contoursBinsPerSemitone

    // MARK: - 窗口化

    /// 相邻窗口重叠的帧数（同时决定重叠采样数）。
    static let overlapFrames = 30
    static let overlapLen = overlapFrames * fftHop
    /// 相邻窗口起点的间隔：43844 - 7680 = 36164。
    static let hopSize = audioNSamples - overlapLen
    /// 每窗保留的帧数：172 - 30 = 142。
    static let framesPerWindow = annotNFrames - overlapFrames

    // MARK: - 后处理默认参数（官方默认值）

    static let onsetThreshold: Float = 0.5
    static let frameThreshold: Float = 0.3
    /// 官方默认 minimum_note_length = 127.7 ms。
    static let minNoteLengthSeconds: Double = 0.1277
    /// 连续多少帧低于阈值判为音符结束。
    static let energyTol = 11
    static let useMelodiaTrick = true
    /// 官方 model_frame_to_time 里的对齐微调量。
    static let magicAlignmentOffset: Double = 0.0018
    /// 音高弯曲在 contour 上的搜索半宽（单位：contour bin）。
    static let pitchBendBinsTolerance = 25

    /// minimum_note_length 折算成帧数（取整后为 11）。
    static var minNoteLengthFrames: Int {
        Int((minNoteLengthSeconds * Double(sampleRate) / Double(fftHop)).rounded())
    }

    // MARK: - 模型接口名（实测确认）

    static let inputName = "input_2"
    static let noteOutputName = "Identity_1"
    static let onsetOutputName = "Identity_2"
    static let contourOutputName = "Identity"

    // MARK: - 音高换算

    private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// MIDI 音高 → 音名，例如 60 → "C4"。
    static func noteName(midi: Int) -> String {
        guard midi >= 0, midi < 128 else { return "?" }
        return "\(noteNames[midi % 12])\(midi / 12 - 1)"
    }

    /// MIDI 音高 → 频率（Hz）。
    static func midiToHz(_ midi: Double) -> Double {
        440.0 * pow(2.0, (midi - 69.0) / 12.0)
    }

    /// MIDI 音高 → contour bin 索引（带小数）。
    static func midiToContourBin(_ midi: Double) -> Double {
        12.0 * Double(contoursBinsPerSemitone) * log2(midiToHz(midi) / baseFrequency)
    }
}
