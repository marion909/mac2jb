import Foundation

enum Paths {
    static let projectRoot: URL = {
        if let env = ProcessInfo.processInfo.environment["MAC2JB_ROOT"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        // gui/Sources/mac2jb_gui/Paths.swift -> repository root
        return URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }()

    static let hblauncher: URL = {
        if let env = ProcessInfo.processInfo.environment["HBLAUNCHER_DIR"], !env.isEmpty {
            return URL(fileURLWithPath: env)
        }
        return projectRoot.deletingLastPathComponent().appendingPathComponent("HBLauncher")
    }()
}
