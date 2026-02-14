import SwiftUI

struct LogStreamView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let podName: String
    let containers: [Container]

    @State private var selectedContainer: String?
    @State private var logLines: [String] = []
    @State private var isStreaming = false
    @State private var error: String?
    @State private var searchText = ""
    @State private var autoScroll = true
    @State private var streamTask: Task<Void, Never>?

    private var displayedLines: [String] {
        if searchText.isEmpty { return logLines }
        return logLines.filter { $0.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("Logs: \(podName)")
                    .font(.headline)

                Spacer()

                if containers.count > 1 {
                    Picker("Container", selection: Binding(
                        get: { selectedContainer ?? containers.first?.name ?? "" },
                        set: { newValue in
                            selectedContainer = newValue
                            restartStream()
                        }
                    )) {
                        ForEach(containers) { c in
                            Text(c.name).tag(c.name)
                        }
                    }
                    .frame(width: 150)
                }

                Toggle("Auto-scroll", isOn: $autoScroll)
                    .toggleStyle(.checkbox)

                Button {
                    logLines.removeAll()
                } label: {
                    Image(systemName: "trash")
                }
                .help("Clear logs")

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle")
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Search
            TextField("Search logs...", text: $searchText)
                .textFieldStyle(.roundedBorder)
                .padding(.horizontal)
                .padding(.vertical, 4)

            // Log content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(displayedLines.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(.caption, design: .monospaced))
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 1)
                                .background(index % 2 == 0 ? Color.clear : Color.primary.opacity(0.03))
                                .id(index)
                        }
                    }
                }
                .onChange(of: logLines.count) {
                    if autoScroll, let last = displayedLines.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }
            .background(.background)

            Divider()

            // Status bar
            HStack {
                Circle()
                    .fill(isStreaming ? .green : .gray)
                    .frame(width: 8, height: 8)
                Text(isStreaming ? "Streaming" : "Disconnected")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("\(displayedLines.count) lines")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let error = error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 4)
            .background(.bar)
        }
        .frame(minWidth: 600, minHeight: 400)
        .task {
            startStream()
        }
        .onDisappear {
            streamTask?.cancel()
        }
    }

    private func startStream() {
        let container = selectedContainer ?? containers.first?.name
        isStreaming = true
        error = nil

        streamTask = Task {
            do {
                for try await line in viewModel.podLogs(
                    name: podName,
                    container: container,
                    tailLines: 200
                ) {
                    logLines.append(line)
                }
                isStreaming = false
            } catch {
                self.error = error.localizedDescription
                isStreaming = false
            }
        }
    }

    private func restartStream() {
        streamTask?.cancel()
        logLines.removeAll()
        startStream()
    }
}
