import Foundation
import Darwin

enum JailbreakStage: Sendable {
    case idle, bootstrap, host, commands, complete, error
}

struct PendingPrompt: Identifiable {
    let id = UUID()
    let message: String
}

@MainActor
final class ProcessManager: ObservableObject {
    @Published var output: [String] = []
    @Published var isRunning = false
    @Published var currentStage: JailbreakStage = .idle
    @Published var progressText = ""
    @Published var errorMessage = ""
    @Published var prompt: PendingPrompt?
    @Published var hostRunning = false

    private let projectRoot = Paths.projectRoot
    private var currentProcess: Process?
    private var currentStdin: FileHandle?
    private var hostProcess: Process?
    private var hostReady = false
    private var partial: [ObjectIdentifier: String] = [:]
    private var lastLine = ""

    func runJailbreak(controller: String, delayMs: Int, bootstrapPath: String) async {
        isRunning = true
        output = []
        errorMessage = ""
        defer { isRunning = false }

        let delay = String(delayMs)

        // Frage, ob Bootstrap neu geschrieben werden soll
        let shouldSendBootstrap = await askBootstrapQuestion()
        if !shouldSendBootstrap {
            append("ℹ️ Bootstrap-Übertragung übersprungen. Verwende existierenden Bootstrap.")
        } else {
            guard await runInteractive(.bootstrap,
                                       executable: projectRoot.appendingPathComponent("mac2jb-send").path,
                                       args: [bootstrapPath, "--delay-ms", delay],
                                       controller: controller) else { return fail() }
        }

        guard await startHost() else { return fail() }

        guard await runInteractive(.commands,
                                   executable: projectRoot.appendingPathComponent("mac2jb-commands").path,
                                   args: ["--delay-ms", delay],
                                   controller: controller) else { return fail() }

        currentStage = .complete
        progressText = "STARTING HBLAUNCHER..."
        append("✅ V=START-Befehl gesendet. Starte HBLauncher...")

        await startHBLauncher()
    }

    func answerPrompt(proceed: Bool) {
        prompt = nil
        if bootstrapQuestionPending {
            bootstrapQuestionPending = false
            bootstrapQuestionContinuation?.resume(returning: proceed)
            bootstrapQuestionContinuation = nil
        } else {
            let reply = proceed ? "\n" : "cancel\n"
            currentStdin?.write(reply.data(using: .utf8)!)
        }
    }

    private var bootstrapQuestionPending = false
    private var bootstrapQuestionContinuation: CheckedContinuation<Bool, Never>?
    private var hblauncherProcess: Process?

    private func askBootstrapQuestion() async -> Bool {
        return await withCheckedContinuation { continuation in
            bootstrapQuestionPending = true
            bootstrapQuestionContinuation = continuation
            prompt = PendingPrompt(message: "Bootstrap neu schreiben? (Weiter) oder verwenden? (Abbrechen)")
        }
    }

    private func startHBLauncher() async {
        guard let localIP = getLocalIP() else {
            append("⚠️ Konnte lokale IP nicht ermitteln. HBLauncher kann nicht automatisch gestartet werden.")
            progressText = "COMPLETE (aber HBLauncher konnte nicht gestartet werden)"
            return
        }

        let hblPath = Paths.hblauncher.path
        let startScript = hblPath + "/start.sh"

        guard FileManager.default.fileExists(atPath: startScript) else {
            append("⚠️ HBLauncher nicht gefunden unter \(hblPath)")
            progressText = "COMPLETE (aber HBLauncher nicht gefunden)"
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [startScript, localIP]
        process.currentDirectoryURL = URL(fileURLWithPath: hblPath)
        process.standardInput = FileHandle.nullDevice

        attachOutput(to: process, isHost: true)
        process.terminationHandler = { p in
            Task { @MainActor [weak self] in
                self?.append("ℹ️ HBLauncher beendet (Exit-Code \(p.terminationStatus)).")
            }
        }

        do {
            try process.run()
            hblauncherProcess = process
            append("✅ HBLauncher gestartet mit IP: \(localIP)")
            progressText = "HBLAUNCHER RUNNING"
        } catch {
            append("⚠️ HBLauncher-Start fehlgeschlagen: \(error.localizedDescription)")
            progressText = "COMPLETE (aber HBLauncher-Start fehlgeschlagen)"
        }
    }

    private func getLocalIP() -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", "ifconfig en0 | grep 'inet ' | awk '{print $2}' || ifconfig en1 | grep 'inet ' | awk '{print $2}' || ifconfig en2 | grep 'inet ' | awk '{print $2}'"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                return output.isEmpty ? nil : output
            }
        } catch {
            return nil
        }
        return nil
    }

    func cancelOperation() {
        prompt = nil
        currentProcess?.terminate()
    }

    func stopHost() {
        hostProcess?.terminate()
    }

    private func fail() {
        currentStage = .error
        if errorMessage.isEmpty { errorMessage = "Abgebrochen." }
    }

    private func baseEnvironment(controller: String) -> [String: String] {
        var env = ProcessInfo.processInfo.environment
        env["MAC2JB_CONTROLLER"] = controller
        env.removeValue(forKey: "MAC2JB_AUTO_WORKER")
        let path = env["PATH"] ?? "/usr/bin:/bin"
        env["PATH"] = "/opt/homebrew/bin:/usr/local/bin:" + path
        return env
    }

    private func runInteractive(_ stage: JailbreakStage, executable: String,
                                args: [String], controller: String) async -> Bool {
        currentStage = stage
        progressText = stage == .bootstrap ? "SENDING BOOTSTRAP..." : "SENDING COMMANDS..."

        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = args
        process.currentDirectoryURL = projectRoot
        process.environment = baseEnvironment(controller: controller)

        let stdin = Pipe()
        process.standardInput = stdin
        attachOutput(to: process)

        let status: Int32 = await withCheckedContinuation { continuation in
            process.terminationHandler = { p in continuation.resume(returning: p.terminationStatus) }
            do {
                try process.run()
            } catch {
                process.terminationHandler = nil
                errorMessage = "Start fehlgeschlagen: \(error.localizedDescription)"
                continuation.resume(returning: -1)
            }
        }
        currentProcess = nil
        currentStdin = nil
        prompt = nil

        if status != 0 && errorMessage.isEmpty {
            errorMessage = "\(stage == .bootstrap ? "Bootstrap" : "Commands") fehlgeschlagen (Exit-Code \(status)). Details in der Konsole."
        }
        return status == 0
    }

    private func startHost() async -> Bool {
        currentStage = .host
        progressText = "STARTING HOST..."

        // Prüfe ob bereits ein aktiver Host existiert
        let activeFile = projectRoot.appendingPathComponent("vendor/ns2jb/runs/mac2jb-active-connect.txt").path
        if FileManager.default.fileExists(atPath: activeFile) {
            do {
                let content = try String(contentsOfFile: activeFile, encoding: .utf8)
                let lines = content.split(separator: "\n", omittingEmptySubsequences: true).map(String.init)
                if lines.count >= 1, let hostPid = Int32(lines[0]), kill(hostPid, 0) == 0 {
                    append("ℹ️ Nutze bestehenden ns2jb-Host (PID: \(hostPid)).")
                    hostRunning = true
                    hostReady = true
                    return true
                }
            } catch {
                append("⚠️ Konnte bestehenden Host nicht überprüfen.")
            }
        }

        hostProcess?.terminate()
        hostReady = false

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [projectRoot.appendingPathComponent("scripts/host.sh").path]
        process.currentDirectoryURL = projectRoot
        process.environment = baseEnvironment(controller: "auto")
        process.standardInput = FileHandle.nullDevice
        attachOutput(to: process, isHost: true)
        process.terminationHandler = { p in
            let code = p.terminationStatus
            Task { @MainActor [weak self] in
                self?.hostRunning = false
                self?.append("ℹ️ ns2jb-Host beendet (Exit-Code \(code)).")
            }
        }

        do {
            try process.run()
        } catch {
            errorMessage = "Host-Start fehlgeschlagen: \(error.localizedDescription)"
            return false
        }
        hostProcess = process
        hostRunning = true

        let deadline = Date().addingTimeInterval(120)
        while !hostReady {
            if !process.isRunning {
                errorMessage = "Der ns2jb-Host wurde beendet, bevor V=START bereitstand."
                return false
            }
            if Date() > deadline {
                errorMessage = "Der ns2jb-Host hat innerhalb von 120 s keinen V=START-Befehl geliefert."
                return false
            }
            try? await Task.sleep(nanoseconds: 200_000_000)
        }
        return true
    }

    private func attachOutput(to process: Process, isHost: Bool = false) {
        let out = Pipe(), err = Pipe()
        process.standardOutput = out
        process.standardError = err
        if !isHost, let stdin = process.standardInput as? Pipe {
            currentProcess = process
            currentStdin = stdin.fileHandleForWriting
        }
        for (pipe, isError) in [(out, false), (err, true)] {
            let key = ObjectIdentifier(pipe)
            pipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    return
                }
                Task { @MainActor [weak self] in
                    self?.consume(data, key: key, isError: isError, isHost: isHost)
                }
            }
        }
    }

    private func consume(_ data: Data, key: ObjectIdentifier, isError: Bool, isHost: Bool) {
        var buffer = (partial[key] ?? "") + String(decoding: data, as: UTF8.self)
        while let range = buffer.rangeOfCharacter(from: CharacterSet(charactersIn: "\r\n")) {
            let line = String(buffer[..<range.lowerBound])
            buffer.removeSubrange(..<range.upperBound)
            handleLine(line, isError: isError, isHost: isHost)
        }
        partial[key] = buffer

        if !isHost, buffer.range(of: "press enter to", options: .caseInsensitive) != nil {
            partial[key] = ""
            append(buffer)
            let text = buffer
                .replacingOccurrences(of: "(type anything to cancel):", with: "")
                .trimmingCharacters(in: .whitespaces)
            let message = text.lowercased().hasPrefix("press enter") ? lastLine : text
            prompt = PendingPrompt(message: message)
        }
    }

    private func handleLine(_ line: String, isError: Bool, isHost: Bool) {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        if trimmed.hasPrefix("Sent line") {
            progressText = "SENDING BOOTSTRAP... (\(trimmed.replacingOccurrences(of: "Sent line ", with: "Zeile ")))"
            if output.last?.hasPrefix("Sent line") == true { output.removeLast() }
        }
        if isHost && trimmed.contains("active V=START command is ready") {
            hostReady = true
        }
        lastLine = trimmed
        append((isHost ? "[host] " : "") + (isError ? "⚠️ " : "") + trimmed)
    }

    private func append(_ line: String) {
        output.append(line)
        if output.count > 2000 { output.removeFirst(output.count - 2000) }
    }
}
