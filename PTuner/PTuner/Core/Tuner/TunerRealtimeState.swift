//
//  TunerRealtimeState.swift
//  PTuner
//
//  调音器的实时读数通道。
//
//  设计目的：把「音频帧频率」的数据（电平、音高、多音读数）从
//  TunerController 的启停、权限、配置状态中分离出来。
//
//  - TunerController 只保留低频状态，根视图与设置页观察它不会因监听而反复刷新；
//  - 只有真正展示实时数据的页面（调音页、和弦页）才观察本对象；
//  - 本对象由 TunerController 以普通属性持有，不作为 @Published 转发，
//    因此不会把高频更新传递给控制器的观察者。
//

import Combine
import Foundation

@MainActor
public final class TunerRealtimeState: ObservableObject {

    // MARK: - 单音通道（CREPE）

    @Published public internal(set) var notes: [TunerNote] = []
    @Published public internal(set) var liveNote: TunerNote?
    /// 平滑后的连续 MIDI 音高；nil 表示当前没有可用的发声。
    @Published public internal(set) var liveMidi: Double?
    @Published public internal(set) var liveConfidence: Float = 0
    @Published public internal(set) var level: Float = 0
    /// 最近 30 秒的逐帧音高，供音高曲线使用。
    @Published public internal(set) var frames: [TunerPitchFrame] = []
    @Published public internal(set) var analyzedSeconds: Double = 0

    // MARK: - 多音识别（Basic Pitch）

    @Published public internal(set) var polyNotes: [TunerNote] = []
    /// 当前同时发声的每个音各一行音准读数，最多 maxPolyphony 行。
    @Published public internal(set) var polyReadouts: [TunerPolyReadout] = []
    @Published public internal(set) var polyAnalyzedSeconds: Double = 0
    @Published public internal(set) var polyInferenceMs: Double = 0

    // MARK: - 派生读数

    public var liveNearestMidi: Int? {
        guard let midi = liveMidi, midi.isFinite else { return nil }
        return Int(midi.rounded())
    }

    public var liveNoteName: String? {
        liveNearestMidi.map { BasicPitchConstants.noteName(midi: $0) }
    }

    public var liveFrequency: Double? {
        guard let midi = liveMidi, midi.isFinite else { return nil }
        return 440.0 * pow(2.0, (midi - 69.0) / 12.0)
    }

    /// 相对最近十二平均律音高的偏差（音分，-50 ~ +50）。
    public var liveCents: Double? {
        guard let midi = liveMidi, midi.isFinite else { return nil }
        return (midi - midi.rounded()) * 100
    }

    public var liveStatusText: String {
        guard let cents = liveCents else { return L10n.tr("等待声音") }
        if abs(cents) <= 5 { return L10n.tr("准") }
        return cents < 0 ? L10n.tr("偏低") : L10n.tr("偏高")
    }

    // MARK: - 重置

    /// 清空所有实时数据。仅在启停或手动清空时调用，不随音频帧触发。
    func reset() {
        notes = []
        liveNote = nil
        liveMidi = nil
        liveConfidence = 0
        level = 0
        frames = []
        analyzedSeconds = 0

        polyNotes = []
        polyReadouts = []
        polyAnalyzedSeconds = 0
        polyInferenceMs = 0
    }
}
