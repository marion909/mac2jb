import SwiftUI

struct ContentView: View {
    @StateObject private var processManager = ProcessManager()
    @State private var systemStatus: SystemStatus?
    @State private var selectedController = "auto"
    @State private var delayMs: Double = 10
    @State private var bootstrapPath = Paths.projectRoot.appendingPathComponent("assets/bootstrap.bas").path
    @State private var showFileDialog = false
    @State private var showCompletionDialog = false
    @State private var showDetails = false

    private let systemChecker = SystemChecker()

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("mac2jb")
                        .font(.system(size: 24, weight: .bold, design: .default))
                    Text("Nintendo Switch 2 Jailbreak Tool")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                Spacer()
                if let status = systemStatus, !status.isReady {
                    Label("System nicht bereit – siehe Details", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(8)

            // Jailbreak Button
            Button(action: startJailbreak) {
                HStack(spacing: 12) {
                    if processManager.isRunning {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "bolt.fill")
                    }
                    Text(processManager.progressText.isEmpty ? "JAILBREAK" : processManager.progressText)
                        .font(.system(size: 18, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(
                    systemStatus?.isReady ?? false ? Color.red : Color.gray
                )
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .disabled(processManager.isRunning || !(systemStatus?.isReady ?? false))

            if processManager.isRunning || processManager.hostRunning {
                HStack {
                    if processManager.isRunning {
                        Button("Abbrechen", role: .cancel) { processManager.cancelOperation() }
                    }
                    Spacer()
                    if processManager.hostRunning {
                        Label("ns2jb-Host läuft", systemImage: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.green)
                        Button("Host stoppen") { processManager.stopHost() }
                    }
                }
            }

            // Error Display
            if !processManager.errorMessage.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Error")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text(processManager.errorMessage)
                            .font(.caption)
                    }
                    Spacer()
                    Button(action: { processManager.errorMessage = "" }) {
                        Image(systemName: "xmark")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
                .background(Color.red.opacity(0.1))
                .cornerRadius(6)
                .border(Color.red.opacity(0.3), width: 1)
            }

            // Details: system status, configuration, console
            DisclosureGroup(isExpanded: $showDetails) {
                VStack(alignment: .leading, spacing: 16) {
                    if let status = systemStatus {
                        HStack(spacing: 16) {
                            StatusIndicator(label: "arm64", isValid: status.isArm64)
                            StatusIndicator(label: "Xcode", isValid: status.hasXcodeTools)
                            StatusIndicator(label: "Node 22", isValid: status.hasNode22)
                            StatusIndicator(label: "kext", isValid: status.hasUsbGadgetKext)
                            Spacer()
                        }
                        .font(.caption)
                    }

                    VStack(alignment: .leading, spacing: 14) {
                        // USB Controller
                        VStack(alignment: .leading, spacing: 6) {
                            Label("USB Controller", systemImage: "cable.connector")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            Picker("", selection: $selectedController) {
                                Text("Auto").tag("auto")
                                Text("usb-drd0").tag("usb-drd0")
                                Text("usb-drd1").tag("usb-drd1")
                                Text("usb-drd3").tag("usb-drd3")
                            }
                            .pickerStyle(.segmented)
                        }

                        Divider()

                        // Delay
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Label("Delay (ms)", systemImage: "clock")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Spacer()
                                Text("\(Int(delayMs))")
                                    .font(.system(size: 14, design: .monospaced))
                                    .frame(width: 40)
                            }
                            Slider(value: $delayMs, in: 1...2000, step: 1)
                        }

                        Divider()

                        // Bootstrap File
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Bootstrap File", systemImage: "doc")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            HStack(spacing: 8) {
                                TextField("Path...", text: $bootstrapPath)
                                    .textFieldStyle(.roundedBorder)
                                    .lineLimit(1)
                                Button(action: { showFileDialog = true }) {
                                    Image(systemName: "folder")
                                        .frame(width: 24, height: 24)
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                    }
                    .padding()
                    .background(Color(nsColor: .controlBackgroundColor))
                    .cornerRadius(8)

                    ConsoleView(output: processManager.output)
                        .frame(minHeight: 200)
                }
                .padding(.top, 8)
            } label: {
                Text("Details (Status, Konfiguration, Konsole)")
                    .font(.headline)
            }

            Spacer(minLength: 0)
        }
        .padding()
        .frame(minWidth: 700, minHeight: 300)
        .onAppear {
            checkSystem()
        }
        .sheet(item: $processManager.prompt) { prompt in
            VStack(alignment: .leading, spacing: 16) {
                Label("Bereit für den nächsten Schritt?", systemImage: "hand.raised.fill")
                    .font(.headline)
                Text(prompt.message)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
                HStack {
                    Button("Abbrechen", role: .cancel) { processManager.answerPrompt(proceed: false) }
                    Spacer()
                    Button("Weiter") { processManager.answerPrompt(proceed: true) }
                        .keyboardShortcut(.defaultAction)
                }
            }
            .padding(24)
            .frame(width: 480)
            .interactiveDismissDisabled()
        }
        .alert("Jailbreak Complete!", isPresented: $showCompletionDialog) {
            Button("Close") {
                processManager.currentStage = .idle
            }
        } message: {
            Text("Bootstrap transfer complete! Your Switch 2 is ready for the next step.")
        }
        .fileImporter(
            isPresented: $showFileDialog,
            allowedContentTypes: [.plainText],
            onCompletion: { result in
                if case .success(let url) = result {
                    bootstrapPath = url.path
                }
            }
        )
    }

    private func checkSystem() {
        systemStatus = systemChecker.checkSystem(bootstrapPath: bootstrapPath)
    }

    private func startJailbreak() {
        Task {
            await processManager.runJailbreak(
                controller: selectedController,
                delayMs: Int(delayMs),
                bootstrapPath: bootstrapPath
            )

            if processManager.currentStage == .complete {
                showCompletionDialog = true
            }
        }
    }
}

struct StatusIndicator: View {
    let label: String
    let isValid: Bool

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(isValid ? Color.green : Color.red)
                .frame(width: 8, height: 8)
            Text(label)
                .font(.caption)
        }
    }
}

#Preview {
    ContentView()
}
