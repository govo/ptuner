//
//  BasicPitchNoteDecoder.swift
//  PTuner
//
//  后处理，逐行移植自 basic_pitch/note_creation.py。
//  参数、遍历顺序、峰值与阈值的先后都与上游一致，不做本地改良。
//

import Foundation

nonisolated struct BasicPitchNote {
    let startFrame: Int
    let endFrame: Int
    let midiPitch: Int
    /// 音符区间内的平均激活值（0 ~ 1），上游称为 amplitude。
    let amplitude: Float
    /// 单位 1/3 半音的音高弯曲序列，长度为 endFrame - startFrame。
    let pitchBends: [Int]

    var frameCount: Int { endFrame - startFrame }
}

nonisolated enum BasicPitchNoteDecoder {

    /// 模型逐帧输出 → 音符事件（帧索引，尚未换算成秒）。
    static func decode(frames: [Float],
                       onsets: [Float],
                       contours: [Float],
                       nFrames: Int) -> [BasicPitchNote] {
        let events = polyphonicNotes(frames: frames, onsets: onsets, nFrames: nFrames)
        return events.map { event in
            BasicPitchNote(startFrame: event.start,
                           endFrame: event.end,
                           midiPitch: event.midi,
                           amplitude: event.amplitude,
                           pitchBends: pitchBends(contours: contours,
                                                  startFrame: event.start,
                                                  endFrame: event.end,
                                                  midiPitch: event.midi))
        }
    }

    /// 帧索引 → 秒。
    ///
    /// 沿用官方 model_frames_to_time 的原式，包括它的窗口索引取法。
    static func timeOfFrame(_ index: Int) -> Double {
        let hopSeconds = Double(BasicPitchConstants.fftHop) / Double(BasicPitchConstants.sampleRate)
        let original = Double(index) * hopSeconds
        let windowNumber = (Double(index) / Double(BasicPitchConstants.annotNFrames)).rounded(.down)
        let windowOffset = hopSeconds
            * (Double(BasicPitchConstants.annotNFrames)
               - Double(BasicPitchConstants.audioNSamples) / Double(BasicPitchConstants.fftHop))
            + BasicPitchConstants.magicAlignmentOffset
        return original - windowOffset * windowNumber
    }

    // MARK: - 内部

    private struct NoteEvent {
        let start: Int
        let end: Int
        let midi: Int
        let amplitude: Float
    }

    /// 移植自 get_infered_onsets：用帧能量的正向跃变补充 onset。
    private static func inferedOnsets(onsets: [Float], frames: [Float], nFrames: Int, nDiff: Int = 2) -> [Float] {
        let bins = BasicPitchConstants.nFreqBinsNotes
        var minDiff = [Float](repeating: .greatestFiniteMagnitude, count: frames.count)

        for n in 1...nDiff {
            for t in 0..<nFrames {
                let currentBase = t * bins
                let previousBase = (t - n) * bins
                for f in 0..<bins {
                    let current = frames[currentBase + f]
                    // 越界的部分按 0 处理，等价于上游在前面补 n 行零。
                    let previous = t - n >= 0 ? frames[previousBase + f] : 0
                    let diff = current - previous
                    let idx = currentBase + f
                    if diff < minDiff[idx] { minDiff[idx] = diff }
                }
            }
        }

        var frameDiff = minDiff.map { $0 < 0 ? 0 : $0 }
        for t in 0..<min(nDiff, nFrames) {
            let base = t * bins
            for f in 0..<bins { frameDiff[base + f] = 0 }
        }

        // 重标定到与 onsets 相同的最大值，再逐点取二者较大者。
        let maxOnset = onsets.max() ?? 0
        let maxDiff = frameDiff.max() ?? 0
        if maxDiff > 0 {
            let scale = maxOnset / maxDiff
            for i in 0..<frameDiff.count { frameDiff[i] *= scale }
        }

        var out = [Float](repeating: 0, count: onsets.count)
        for i in 0..<onsets.count { out[i] = max(onsets[i], frameDiff[i]) }
        return out
    }

    /// 移植自 output_to_notes_polyphonic。
    private static func polyphonicNotes(frames: [Float], onsets: [Float], nFrames: Int) -> [NoteEvent] {
        let bins = BasicPitchConstants.nFreqBinsNotes
        /// 上游 `MAX_FREQ_IDX = 87`：置零邻频带时的上界。
        let maxFreqIdx = bins - 1
        let minNoteLen = BasicPitchConstants.minNoteLengthFrames
        let energyTol = BasicPitchConstants.energyTol
        let frameThreshold = BasicPitchConstants.frameThreshold

        let inferred = inferedOnsets(onsets: onsets, frames: frames, nFrames: nFrames)

        // scipy.signal.argrelmax(axis=0, order=1, mode='clip') 的等价实现：
        // 沿时间轴严格大于前后各 1 帧；首尾帧不可能成为峰值。
        var peaks = [Float](repeating: 0, count: inferred.count)
        if nFrames > 2 {
            for t in 1..<(nFrames - 1) {
                let base = t * bins
                let previous = base - bins
                let next = base + bins
                for f in 0..<bins {
                    let value = inferred[base + f]
                    if value > inferred[previous + f] && value > inferred[next + f] {
                        peaks[base + f] = value
                    }
                }
            }
        }

        // np.where 是行优先升序，反转后即为「时间倒序、同帧内频率倒序」。
        var order: [(t: Int, f: Int)] = []
        for t in 0..<nFrames {
            let base = t * bins
            for f in 0..<bins where peaks[base + f] >= BasicPitchConstants.onsetThreshold {
                order.append((t, f))
            }
        }
        order.reverse()

        var remaining = frames
        var events: [NoteEvent] = []

        for (start, f) in order {
            if start >= nFrames - 1 { continue }

            var i = start + 1
            var k = 0
            while i < nFrames - 1 && k < energyTol {
                if remaining[i * bins + f] < frameThreshold { k += 1 } else { k = 0 }
                i += 1
            }
            i -= k

            if i - start <= minNoteLen { continue }

            for t in start..<i {
                remaining[t * bins + f] = 0
                if f < maxFreqIdx { remaining[t * bins + f + 1] = 0 }
                if f > 0 { remaining[t * bins + f - 1] = 0 }
            }

            var sum: Float = 0
            for t in start..<i { sum += frames[t * bins + f] }
            events.append(NoteEvent(start: start,
                                    end: i,
                                    midi: f + BasicPitchConstants.midiOffset,
                                    amplitude: sum / Float(i - start)))
        }

        if BasicPitchConstants.useMelodiaTrick {
            // 反复取全局最大能量处作为新音符，并向两侧扩展。
            // 取最大值时保持上游 argmax 的行优先语义（时间小者优先，再比频率小者）。
            while true {
                var best: Float = -1
                var bestIndex = -1
                for index in 0..<remaining.count where remaining[index] > best {
                    best = remaining[index]
                    bestIndex = index
                }
                if bestIndex < 0 || best <= frameThreshold { break }

                let mid = bestIndex / bins
                let f = bestIndex % bins
                remaining[mid * bins + f] = 0

                var i = mid + 1
                var k = 0
                while i < nFrames - 1 && k < energyTol {
                    if remaining[i * bins + f] < frameThreshold { k += 1 } else { k = 0 }
                    remaining[i * bins + f] = 0
                    if f < maxFreqIdx { remaining[i * bins + f + 1] = 0 }
                    if f > 0 { remaining[i * bins + f - 1] = 0 }
                    i += 1
                }
                let end = i - 1 - k

                i = mid - 1
                k = 0
                while i > 0 && k < energyTol {
                    if remaining[i * bins + f] < frameThreshold { k += 1 } else { k = 0 }
                    remaining[i * bins + f] = 0
                    if f < maxFreqIdx { remaining[i * bins + f + 1] = 0 }
                    if f > 0 { remaining[i * bins + f - 1] = 0 }
                    i -= 1
                }
                let begin = i + 1 + k

                if end - begin <= minNoteLen { continue }

                var sum: Float = 0
                for t in begin..<end { sum += frames[t * bins + f] }
                events.append(NoteEvent(start: begin,
                                        end: end,
                                        midi: f + BasicPitchConstants.midiOffset,
                                        amplitude: sum / Float(end - begin)))
            }
        }

        return events
    }

    /// 移植自 get_pitch_bends：在 contour 上按音符音高附近加高斯窗后取 argmax。
    private static func pitchBends(contours: [Float],
                                   startFrame: Int,
                                   endFrame: Int,
                                   midiPitch: Int) -> [Int] {
        let tolerance = BasicPitchConstants.pitchBendBinsTolerance
        let contourBins = BasicPitchConstants.nFreqBinsContours
        let windowLength = tolerance * 2 + 1

        let centerBin = Int(BasicPitchConstants.midiToContourBin(Double(midiPitch)).rounded())
        let binStart = max(centerBin - tolerance, 0)
        let binEnd = min(contourBins, centerBin + tolerance + 1)
        let gaussianStart = max(0, tolerance - centerBin)
        let gaussianEnd = windowLength - max(0, centerBin - (contourBins - tolerance - 1))
        let shift = tolerance - gaussianStart

        let count = endFrame - startFrame
        guard count > 0, binEnd > binStart, gaussianEnd > gaussianStart else { return [] }

        let gaussian = gaussianWindow(length: windowLength)
        let span = binEnd - binStart

        var out = [Int](repeating: 0, count: count)
        for t in 0..<count {
            let row = (startFrame + t) * contourBins
            var best = -Float.greatestFiniteMagnitude
            var bestOffset = 0
            for k in 0..<span {
                let weight = gaussian[gaussianStart + k]
                let value = contours[row + binStart + k] * weight
                if value > best {
                    best = value
                    bestOffset = k
                }
            }
            out[t] = bestOffset - shift
        }
        return out
    }

    /// 等价于 scipy.signal.windows.gaussian(length, std=5)：
    /// w[i] = exp(-(i - (length-1)/2)^2 / (2 * std^2))。
    private static func gaussianWindow(length: Int, std: Double = 5) -> [Float] {
        let half = Double(length - 1) / 2.0
        return (0..<length).map { i in
            let n = Double(i) - half
            return Float(exp(-(n * n) / (2.0 * std * std)))
        }
    }
}
