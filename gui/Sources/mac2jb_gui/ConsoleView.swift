import SwiftUI

struct ConsoleView: View {
    let output: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Console Output")
                    .font(.headline)
                Spacer()
                Button(action: copyToClipboard) {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .help("Copy console output")
            }
            .padding(.bottom, 4)

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(output.enumerated()), id: \.offset) { index, line in
                            HStack(alignment: .top, spacing: 0) {
                                Text(line)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(lineColor(for: line))
                                    .textSelection(.enabled)
                                Spacer()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .id(index)
                        }
                    }
                }
                .onChange(of: output.count) {
                    if let lastIndex = output.indices.last {
                        withAnimation {
                            proxy.scrollTo(lastIndex, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .border(Color.gray.opacity(0.3))
        .cornerRadius(6)
    }

    private func lineColor(for line: String) -> Color {
        if line.contains("error") || line.contains("Error") || line.contains("ERROR") {
            return .red
        } else if line.contains("Sent line") || line.contains("progress") {
            return .yellow
        } else if line.contains("complete") || line.contains("Complete") || line.contains("success") {
            return .green
        }
        return .primary
    }

    private func copyToClipboard() {
        let allOutput = output.joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(allOutput, forType: .string)
    }
}

#Preview {
    ConsoleView(output: [
        "Mac2JB Bootstrap Transfer",
        "Verified 7804 input bytes, 7804 keystrokes, 100 newline(s).",
        "Sent line 1",
        "Sent line 2",
        "Sent line 3",
        "Transfer complete!"
    ])
    .padding()
}
