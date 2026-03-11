import SwiftUI

struct NodeListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selectedNode: Node?
    @State private var sortOrder = [KeyPathComparator(\Node.name)]

    private var sorted: [Node] {
        viewModel.nodes.sorted(using: sortOrder)
    }

    var body: some View {
        HSplitView {
            Table(sorted, selection: Binding(
                get: { selectedNode?.id },
                set: { id in selectedNode = sorted.first { $0.id == id } }
            ), sortOrder: $sortOrder) {
                TableColumn("Status") { node in
                    StatusBadge(status: node.isReady ? .healthy : .error)
                }
                .width(40)

                TableColumn("Name", sortUsing: KeyPathComparator(\.name)) { node in
                    Text(node.name)
                }
                .width(min: 150, ideal: 250)

                TableColumn("IP") { node in
                    Text(node.internalIP ?? "-")
                        .monospacedDigit()
                }
                .width(120)

                TableColumn("Version", sortUsing: KeyPathComparator(\.sortableVersion)) { node in
                    Text(node.kubeletVersion ?? "-")
                }
                .width(100)

                TableColumn("OS") { node in
                    Text(node.osImage ?? "-")
                        .foregroundStyle(.secondary)
                }
                .width(min: 100, ideal: 150)

                TableColumn("Age", sortUsing: KeyPathComparator(\.sortableAge)) { node in
                    Text(formatAge(from: node.metadata.creationTimestamp))
                }
                .width(50)

                if viewModel.metricsAvailable {
                    TableColumn("CPU") { node in
                        Text(viewModel.metrics(for: node).map { formatMillicores($0.cpuMillicores) } ?? "-")
                            .monospacedDigit()
                    }
                    .width(60)

                    TableColumn("Memory") { node in
                        Text(viewModel.metrics(for: node).map { formatBytes($0.memoryBytes) } ?? "-")
                            .monospacedDigit()
                    }
                    .width(70)
                }
            }
            .frame(minWidth: 400)

            if let node = selectedNode {
                NodeDetailPanel(node: node)
                    .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .navigationTitle("Nodes")
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "Node" else { return }
        if let match = viewModel.nodes.first(where: { $0.name == pending.name }) {
            selectedNode = match
            viewModel.pendingSelection = nil
        }
    }
}

struct NodeDetailPanel: View {
    @Environment(ClusterViewModel.self) private var viewModel
    let node: Node
    @State private var detailTab: DetailTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            DetailTabPicker(selection: $detailTab)
            if detailTab == .yaml {
                RawResourceView(resource: node)
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        StatusBadge(status: node.isReady ? .healthy : .error)
                        Text(node.name)
                            .font(.headline)
                    }

                    Divider()

                    DetailSection(title: "Info") {
                        DetailRow(label: "IP", value: node.internalIP ?? "-")
                        DetailRow(label: "Kubelet", value: node.kubeletVersion ?? "-")
                        DetailRow(label: "OS", value: node.osImage ?? "-")
                        DetailRow(
                            label: "Runtime",
                            value: node.status?.nodeInfo?.containerRuntimeVersion ?? "-"
                        )
                        DetailRow(
                            label: "Arch",
                            value: node.status?.nodeInfo?.architecture ?? "-"
                        )
                        DetailRow(
                            label: "Age",
                            value: formatAge(from: node.metadata.creationTimestamp)
                        )
                    }

                    if let capacity = node.status?.capacity, !capacity.isEmpty {
                        DetailSection(title: "Capacity") {
                            DetailRow(label: "CPU", value: capacity["cpu"] ?? "-")
                            DetailRow(label: "Memory", value: capacity["memory"] ?? "-")
                            DetailRow(label: "Pods", value: capacity["pods"] ?? "-")
                        }
                    }

                    if viewModel.metricsAvailable, let m = viewModel.metrics(for: node) {
                        let allocCPU = parseMillicores(node.status?.allocatable?["cpu"]) ?? 1
                        let allocMem = parseMemoryBytes(node.status?.allocatable?["memory"]) ?? 1
                        DetailSection(title: "Usage") {
                            MetricsBar(
                                label: "CPU",
                                usedText: formatMillicores(m.cpuMillicores),
                                totalText: formatMillicores(allocCPU),
                                fraction: min(1.0, Double(m.cpuMillicores) / Double(allocCPU))
                            )
                            MetricsBar(
                                label: "Memory",
                                usedText: formatBytes(m.memoryBytes),
                                totalText: formatBytes(allocMem),
                                fraction: min(1.0, Double(m.memoryBytes) / Double(allocMem))
                            )
                        }
                    }

                    ResourceTreeSection(nodes: viewModel.relatedTreeForNode(node))

                    RelatedEventsSection(resourceKind: "Node", resourceName: node.name)

                    if let conditions = node.status?.conditions, !conditions.isEmpty {
                        DetailSection(title: "Conditions") {
                            ForEach(conditions, id: \.type) { cond in
                                HStack {
                                    StatusBadge(
                                        status: conditionStatus(type: cond.type, value: cond.status)
                                    )
                                    Text(cond.type)
                                        .font(.callout)
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            }
        }
    }

    private func conditionStatus(type: String, value: String) -> StatusBadge.Status {
        // "Ready" should be True; other conditions (MemoryPressure, DiskPressure, etc.) should be False
        if type == "Ready" {
            return value == "True" ? .healthy : .error
        }
        return value == "False" ? .healthy : .warning
    }
}
