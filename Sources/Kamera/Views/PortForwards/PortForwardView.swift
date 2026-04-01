import SwiftUI

// MARK: - PortForwardsView (main content panel)

struct PortForwardsView: View {
    @Environment(PortForwardManager.self) private var manager

    var body: some View {
        if manager.forwards.isEmpty {
            emptyState
        } else {
            forwardsList
        }
    }

    // MARK: Empty State

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "arrow.left.arrow.right.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("No Active Port Forwards")
                .font(.title3)
                .fontWeight(.medium)
            Text("Start a port forward from a Pod or Service detail panel.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle("Port Forwards")
    }

    // MARK: Forwards List

    private var forwardsList: some View {
        List {
            ForEach(manager.forwards) { forward in
                ForwardRow(forward: forward)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
            }
        }
        .listStyle(.inset)
        .navigationTitle("Port Forwards")
        .toolbar {
            ToolbarItem {
                Button(role: .destructive) {
                    manager.stopAll()
                } label: {
                    Label("Stop All", systemImage: "stop.circle")
                }
                .help("Stop all port forwards")
                .disabled(manager.forwards.isEmpty)
            }
        }
    }
}

// MARK: - Forward Row

private struct ForwardRow: View {
    @Environment(PortForwardManager.self) private var manager
    let forward: PortForwardManager.Forward

    var body: some View {
        HStack(spacing: 12) {
            statusIndicator

            VStack(alignment: .leading, spacing: 2) {
                Text(forward.displayTitle)
                    .font(.callout)
                    .fontWeight(.medium)
                Text("localhost:\(forward.localPort) → \(forward.remotePort)")
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                if case .failed(let msg) = forward.status {
                    Text(msg)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .lineLimit(2)
                }
            }

            Spacer()

            if forward.status == .active, let url = forward.localURL {
                Button {
                    NSWorkspace.shared.open(url)
                } label: {
                    Image(systemName: "safari")
                }
                .buttonStyle(.borderless)
                .help("Open in browser")
            }

            Button {
                manager.stopForward(id: forward.id)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.borderless)
            .help("Stop port forward")
        }
        .padding(.vertical, 2)
    }

    private var statusIndicator: some View {
        Group {
            switch forward.status {
            case .starting:
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 10, height: 10)
            case .active:
                Circle()
                    .fill(.green)
                    .frame(width: 10, height: 10)
            case .failed:
                Circle()
                    .fill(.red)
                    .frame(width: 10, height: 10)
            }
        }
    }
}

// MARK: - PortForwardStartSheet

struct PortForwardStartSheet: View {
    @Environment(PortForwardManager.self) private var manager
    @Environment(ClusterViewModel.self) private var viewModel
    @Environment(\.dismiss) private var dismiss

    let resourceType: PortForwardManager.Forward.ResourceType
    let resourceName: String
    let namespace: String
    let suggestedPorts: [Int]

    @State private var selectedRemotePort: Int
    @State private var localPortText: String
    @State private var isStarting = false
    @State private var error: String?

    init(
        resourceType: PortForwardManager.Forward.ResourceType,
        resourceName: String,
        namespace: String,
        suggestedPorts: [Int]
    ) {
        self.resourceType = resourceType
        self.resourceName = resourceName
        self.namespace = namespace
        self.suggestedPorts = suggestedPorts

        let defaultPort = suggestedPorts.first ?? 8080
        _selectedRemotePort = State(initialValue: defaultPort)
        _localPortText = State(initialValue: "\(defaultPort)")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Port Forward")
                        .font(.headline)
                    Text("\(resourceType.displayName)/\(resourceName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()

            // Form
            VStack(alignment: .leading, spacing: 16) {
                // Remote port
                VStack(alignment: .leading, spacing: 4) {
                    Text("Remote Port")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if suggestedPorts.isEmpty {
                        TextField("Port number", text: Binding(
                            get: { "\(selectedRemotePort)" },
                            set: { if let v = Int($0) { selectedRemotePort = v } }
                        ))
                        .textFieldStyle(.roundedBorder)
                    } else {
                        Picker("Remote Port", selection: $selectedRemotePort) {
                            ForEach(suggestedPorts, id: \.self) { port in
                                Text("\(port)").tag(port)
                            }
                        }
                        .labelsHidden()
                        .onChange(of: selectedRemotePort) { _, newPort in
                            localPortText = "\(newPort)"
                        }
                    }
                }

                // Local port
                VStack(alignment: .leading, spacing: 4) {
                    Text("Local Port")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    TextField("Local port", text: $localPortText)
                        .textFieldStyle(.roundedBorder)
                }

                if let error {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .padding()

            Divider()

            // Actions
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Button {
                    startForward()
                } label: {
                    if isStarting {
                        HStack(spacing: 6) {
                            ProgressView().controlSize(.small)
                            Text("Starting…")
                        }
                    } else {
                        Text("Start Forward")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(isStarting || localPort == nil)
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 320)
    }

    private var localPort: Int? {
        Int(localPortText)
    }

    private func startForward() {
        guard let lp = localPort else {
            error = "Invalid local port"
            return
        }
        guard let context = viewModel.selectedContext else {
            error = "No cluster context selected"
            return
        }
        isStarting = true
        error = nil

        Task {
            await manager.startForward(
                context: context,
                resourceType: resourceType,
                resourceName: resourceName,
                namespace: namespace,
                localPort: lp,
                remotePort: selectedRemotePort
            )
            dismiss()
        }
    }
}
