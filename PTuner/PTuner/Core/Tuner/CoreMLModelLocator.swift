//
//  CoreMLModelLocator.swift
//  PTuner
//
//  统一的 CoreML 模型查找。
//
//  .mlpackage 由 Xcode 在构建期编译为 .mlmodelc 放进 app bundle；同步目录
//  （PBXFileSystemSynchronizedRootGroup）不会保留源目录结构，资源默认平铺在
//  bundle 根目录。同时兼容把模型放在 Resources/Models 子目录的情况。
//

import Foundation

nonisolated enum CoreMLModelLocator {

    private static let extensions = ["mlmodelc", "mlpackage", "mlmodel"]
    private static let subdirectories: [String?] = [nil, "Models", "Resources/Models"]

    static func locate(_ name: String, in bundle: Bundle = .main) -> URL? {
        for subdirectory in subdirectories {
            for ext in extensions {
                if let url = bundle.url(forResource: name,
                                        withExtension: ext,
                                        subdirectory: subdirectory) {
                    return url
                }
            }
        }
        return nil
    }
}
