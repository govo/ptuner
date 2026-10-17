//
//  BasicPitchModel.swift
//  PTuner
//
//  加载 Basic Pitch CoreML 模型并按窗推理。
//
//  输出必须按真实 strides 读取：同一份输出在不同计算单元下每行可能被补齐
//  （实测 note 行宽在 96 与 88 之间变化），按 shape 连乘会读到错位数据。
//

import CoreML
import Foundation

nonisolated enum BasicPitchModelError: Error {
    case modelNotFound(String)
    case loadFailed(Error)
    case inferenceFailed(Error)
    case unexpectedDataType(Int)
    case outputMissing(String)
    case outputShapeMismatch(String)
}

/// 单个窗口的模型输出。三个矩阵都是紧凑的 (frames × bins) 行优先数组。
nonisolated struct BasicPitchWindowOutput {
    let frames: Int
    let noteFrames: [Float]
    let onsetFrames: [Float]
    let contourFrames: [Float]
}

nonisolated final class BasicPitchModel {

    /// 实际生效的计算单元描述；如果推理时回退过，会在这里标记出来。
    private(set) var computeUnitsLabel: String
    let loadElapsedMs: Double

    private let modelURL: URL
    private var model: MLModel
    private let lock = NSLock()
    private var cpuFallback: MLModel?

    init(modelName: String = "BasicPitch") throws {
        let start = CFAbsoluteTimeGetCurrent()

        guard let url = CoreMLModelLocator.locate(modelName) else {
            throw BasicPitchModelError.modelNotFound(modelName)
        }
        self.modelURL = url

        var loaded: MLModel?
        var label = "all"
        do {
            let cfg = MLModelConfiguration()
            cfg.computeUnits = .all
            loaded = try MLModel(contentsOf: url, configuration: cfg)
        } catch {
            loaded = nil
        }
        if loaded == nil {
            do {
                let cfg = MLModelConfiguration()
                cfg.computeUnits = .cpuOnly
                loaded = try MLModel(contentsOf: url, configuration: cfg)
                label = "cpuOnly"
            } catch {
                throw BasicPitchModelError.loadFailed(error)
            }
        }
        guard let ready = loaded else {
            throw BasicPitchModelError.modelNotFound(modelName)
        }

        self.model = ready
        self.computeUnitsLabel = label
        self.loadElapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
    }

    /// 预热：首窗包含一次性的图编译（实测 macOS 上约 3 秒）。
    func warmUp() {
        _ = try? predict(window: [Float](repeating: 0, count: BasicPitchConstants.audioNSamples))
    }

    /// 单窗推理。window 长度必须是 audioNSamples（43844）。
    func predict(window: [Float]) throws -> BasicPitchWindowOutput {
        precondition(window.count == BasicPitchConstants.audioNSamples,
                     "窗口长度必须是 \(BasicPitchConstants.audioNSamples)")
        let input = try makeInput(window)
        let provider = try MLDictionaryFeatureProvider(
            dictionary: [BasicPitchConstants.inputName: MLFeatureValue(multiArray: input)]
        )

        do {
            return try extract(from: try activeModel.prediction(from: provider))
        } catch {
            guard let cpu = makeCPUFallbackIfNeeded() else {
                throw BasicPitchModelError.inferenceFailed(error)
            }
            do {
                return try extract(from: try cpu.prediction(from: provider))
            } catch {
                throw BasicPitchModelError.inferenceFailed(error)
            }
        }
    }

    // MARK: - 内部

    private var activeModel: MLModel {
        lock.lock()
        defer { lock.unlock() }
        return model
    }

    private func makeCPUFallbackIfNeeded() -> MLModel? {
        lock.lock()
        defer { lock.unlock() }
        if let existing = cpuFallback { return existing }
        let cfg = MLModelConfiguration()
        cfg.computeUnits = .cpuOnly
        guard let cpu = try? MLModel(contentsOf: modelURL, configuration: cfg) else { return nil }
        cpuFallback = cpu
        model = cpu
        computeUnitsLabel += " → 推理时回退 cpuOnly"
        return cpu
    }

    private func makeInput(_ window: [Float]) throws -> MLMultiArray {
        let n = BasicPitchConstants.audioNSamples
        let arr = try MLMultiArray(shape: [1, NSNumber(value: n), 1], dataType: .float32)
        let dst = arr.dataPointer.bindMemory(to: Float.self, capacity: n)
        window.withUnsafeBufferPointer { src in
            guard let base = src.baseAddress else { return }
            dst.update(from: base, count: n)
        }
        return arr
    }

    private func extract(from out: MLFeatureProvider) throws -> BasicPitchWindowOutput {
        let frames = BasicPitchConstants.annotNFrames
        guard let note = out.featureValue(for: BasicPitchConstants.noteOutputName)?.multiArrayValue else {
            throw BasicPitchModelError.outputMissing(BasicPitchConstants.noteOutputName)
        }
        guard let onset = out.featureValue(for: BasicPitchConstants.onsetOutputName)?.multiArrayValue else {
            throw BasicPitchModelError.outputMissing(BasicPitchConstants.onsetOutputName)
        }
        guard let contour = out.featureValue(for: BasicPitchConstants.contourOutputName)?.multiArrayValue else {
            throw BasicPitchModelError.outputMissing(BasicPitchConstants.contourOutputName)
        }
        return BasicPitchWindowOutput(
            frames: frames,
            noteFrames: try multiArrayToFrames(note, frames: frames, bins: BasicPitchConstants.nFreqBinsNotes),
            onsetFrames: try multiArrayToFrames(onset, frames: frames, bins: BasicPitchConstants.nFreqBinsNotes),
            contourFrames: try multiArrayToFrames(contour, frames: frames, bins: BasicPitchConstants.nFreqBinsContours)
        )
    }

    /// 把模型输出的多维数组按真实 strides 拷成紧凑的 (frames × bins) 行优先数组。
    private func multiArrayToFrames(_ ma: MLMultiArray, frames: Int, bins: Int) throws -> [Float] {
        guard ma.dataType == .float32 else {
            throw BasicPitchModelError.unexpectedDataType(ma.dataType.rawValue)
        }
        let shape = ma.shape.map { $0.intValue }
        guard shape.count >= 3, shape[1] == frames, shape[2] == bins else {
            throw BasicPitchModelError.outputShapeMismatch("\(shape) 不等于 [1, \(frames), \(bins)]")
        }

        let strides = ma.strides.map { $0.intValue }

        // 缓冲区跨度必须按 strides 推导：补齐布局下 ma.count 会小于真实跨度。
        var span = 1
        for i in 0..<shape.count {
            span += (shape[i] - 1) * strides[i]
        }

        let src = ma.dataPointer.bindMemory(to: Float.self, capacity: span)
        let rowStride = strides[1]
        let columnStride = strides[2]

        var out = [Float](repeating: 0, count: frames * bins)
        out.withUnsafeMutableBufferPointer { dst in
            for f in 0..<frames {
                let srcBase = f * rowStride
                let dstBase = f * bins
                for b in 0..<bins {
                    dst[dstBase + b] = src[srcBase + b * columnStride]
                }
            }
        }
        return out
    }
}
