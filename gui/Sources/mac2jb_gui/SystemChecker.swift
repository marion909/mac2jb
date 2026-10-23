import Foundation

struct SystemStatus {
    let isArm64: Bool
    let hasXcodeTools: Bool
    let hasNode22: Bool
    let hasUsbGadgetKext: Bool
    let bootstrapFileExists: Bool
    let hasMac2jbSend: Bool
    let hasMac2jbCommands: Bool

    var isReady: Bool {
        isArm64 && hasXcodeTools && hasNode22 && hasUsbGadgetKext && bootstrapFileExists && hasMac2jbSend && hasMac2jbCommands
    }
}

class SystemChecker {
    private let projectRoot = Paths.projectRoot.path

    func checkSystem(bootstrapPath: String) -> SystemStatus {
        return SystemStatus(
            isArm64: checkArm64(),
            hasXcodeTools: checkXcodeTools(),
            hasNode22: checkNode22(),
            hasUsbGadgetKext: checkUsbGadgetKext(),
            bootstrapFileExists: checkBootstrapFile(bootstrapPath),
            hasMac2jbSend: checkMacBinary("mac2jb-send"),
            hasMac2jbCommands: checkMacBinary("mac2jb-commands")
        )
    }

    private func checkArm64() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/uname")
        process.arguments = ["-m"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return output == "arm64"
        } catch {
            return false
        }
    }

    private func checkXcodeTools() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        process.arguments = ["xcrun"]

        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    private func checkNode22() -> Bool {
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["node"]

        let whichPipe = Pipe()
        which.standardOutput = whichPipe

        do {
            try which.run()
            which.waitUntilExit()

            if which.terminationStatus != 0 { return false }

            let data = whichPipe.fileHandleForReading.readDataToEndOfFile()
            guard let nodePath = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !nodePath.isEmpty else {
                return false
            }

            let version = Process()
            version.executableURL = URL(fileURLWithPath: nodePath)
            version.arguments = ["--version"]

            let versionPipe = Pipe()
            version.standardOutput = versionPipe

            try version.run()
            version.waitUntilExit()

            let versionData = versionPipe.fileHandleForReading.readDataToEndOfFile()
            guard let versionStr = String(data: versionData, encoding: .utf8) else { return false }

            let majorVersion = extractMajorVersion(from: versionStr)
            return majorVersion >= 22
        } catch {
            return false
        }
    }

    private func extractMajorVersion(from versionString: String) -> Int {
        let parts = versionString.split(separator: ".")
        if let firstPart = parts.first, let major = Int(firstPart.trimmingCharacters(in: .letters)) {
            return major
        }
        return 0
    }

    private func checkUsbGadgetKext() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/kmutil")
        process.arguments = ["showloaded"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return output.lowercased().contains("usbgadget") || output.lowercased().contains("gay.bowser")
        } catch {
            return false
        }
    }

    private func checkBootstrapFile(_ path: String) -> Bool {
        FileManager.default.fileExists(atPath: path)
    }

    private func checkMacBinary(_ name: String) -> Bool {
        let path = "\(projectRoot)/\(name)"
        return FileManager.default.fileExists(atPath: path) && FileManager.default.isExecutableFile(atPath: path)
    }
}
