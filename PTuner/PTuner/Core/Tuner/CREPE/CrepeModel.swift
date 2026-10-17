//
//  CrepeModel.swift
//  PTuner
//
//  加载 CREPE CoreML 模型并按批推理。
//
//  输出必须按真实 strides 读取，不能按 shape 连乘索引：同一份输出的 strides
//  会随计算单元变化，按 shape 索引会读到补位/错行数据。
//

import CoreML
import Foundation

nonisolated enum CrepeModelError: Error {
    case modelNotFound(String)
    case loadFailed(Error)
    case inferenceFailed(Error)
    case unexpectedDataType(Int)
    case outputMissing(String)
    case outputShapeMismatch(String)
    case emptyInput
}

nonisolated final class CrepeModel {

    /// 实际生效的计算单元描述；如果推理时回退过，会在这里标记出来。
    private(set) var computeUnitsLabel: String
    let loadElapsedMs: Double

    private let modelURL: URL
    private var model: MLModel
    private let lock = NSLock()
    private var cpuFallback: MLModel?

    init(modelName: String = CrepeConstants.modelName) throws {
        let start = CFAbsoluteTimeGetCurrent()

        guard let url = CoreMLModelLocator.locate(modelName) else {
            throw CrepeModelError.modelNotFound(modelName)
        }
        self.modelURL = url

        // 优先用全部计算单元（GPU / 神经网络引擎），模拟器上后端可能直接加载失败，
        // 那就退回 CPU。
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
                throw CrepeModelError.loadFailed(error)
            }
        }
        guard let ready = loaded else { throw CrepeModelError.modelNotFound(modelName) }

        self.model = ready
        self.computeUnitsLabel = label
        self.loadElapsedMs = (CFAbsoluteTimeGetCurrent() - start) * 1000.0
    }

    /// 预热：首帧包含一次性的图编译，先跑一次并丢弃结果，否则耗时统计会失真。
    func warmUp() {
        _ = try? predict(frames: [Float](repeating: 0, count: CrepeConstants.windowSize),
                         frameCount: 1)
    }

    /// 批量推理。frames 是 frameCount × windowSize 的行优先扁平数组，
    /// 每帧必须已经做过逐帧归一化（见 TunerEngine）。
    /// 返回 frameCount × pitchBins 的行优先扁平激活值（已过 sigmoid）。
    func predict(frames: [Float], frameCount: Int) throws -> [Float] {
        guard frameCount > 0 else { throw CrepeModelError.emptyInput }
        let window = CrepeConstants.windowSize
        precondition(frames.count == frameCount * window,
                     "输入长度必须是 frameCount × \(window)")

        let input = try makeInput(frames: frames, frameCount: frameCount)
        let provider = try MLDictionaryFeatureProvider(
            dictionary: [CrepeConstants.inputName: MLFeatureValue(multiArray: input)]
        )

        do {
            return try extract(from: try activeModel.prediction(from: provider),
                               frameCount: frameCount)
        } catch {
            // 计算单元加载成功但推理不被支持时，退回 CPU 再试一次。
            guard let cpu = makeCPUFallbackIfNeeded() else {
                throw CrepeModelError.inferenceFailed(error)
            }
            do {
                return try extract(from: try cpu.prediction(from: provider),
                                   frameCount: frameCount)
            } catch {
                throw CrepeModelError.inferenceFailed(error)
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

    private func makeInput(frames: [Float], frameCount: Int) throws -> MLMultiArray {
        let window = CrepeConstants.windowSize
        let arr = try MLMultiArray(shape: [NSNumber(value: frameCount), NSNumber(value: window)],
                                   dataType: .float32)
        let dst = arr.dataPointer.bindMemory(to: Float.self, capacity: frameCount * window)
        frames.withUnsafeBufferPointer { src in
            guard let base = src.baseAddress else { return }
            dst.update(from: base, count: frameCount * window)
        }
        return arr
    }

    private func extract(from out: MLFeatureProvider, frameCount: Int) throws -> [Float] {
        guard let activations = out.featureValue(for: CrepeConstants.outputName)?.multiArrayValue else {
            throw CrepeModelError.outputMissing(CrepeConstants.outputName)
        }
        return try multiArrayToActivations(activations, frameCount: frameCount)
    }

    /// 把模型输出的多维数组按真实 strides 拷成紧凑的 (frames × bins) 行优先数组。
    private func multiArrayToActivations(_ ma: MLMultiArray, frameCount: Int) throws -> [Float] {
        guard ma.dataType == .float32 else {
            throw CrepeModelError.unexpectedDataType(ma.dataType.rawValue)
        }
        let bins = CrepeConstants.pitchBins
        let shape = ma.shape.map { $0.intValue }
        guard shape.count >= 2, shape[0] == frameCount, shape[1] == bins else {
            throw CrepeModelError.outputShapeMismatch("\(shape) 不等于 [\(frameCount), \(bins)]")
        }

        let strides = ma.strides.map { $0.intValue }

        // 缓冲区跨度必须按 strides 推导：补齐布局下 ma.count 会小于真实跨度。
        var span = 1
        for i in 0..<shape.count {
            span += (shape[i] - 1) * strides[i]
        }

        let src = ma.dataPointer.bindMemory(to: Float.self, capacity: span)
        let rowStride = strides[0]
        let columnStride = strides[1]

        var out = [Float](repeating: 0, count: frameCount * bins)
        out.withUnsafeMutableBufferPointer { dst in
            for f in 0..<frameCount {
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
