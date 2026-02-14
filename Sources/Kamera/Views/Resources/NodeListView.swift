import SwiftUI

struct NodeListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selectedNode: Node?

    var body: some View {
        HSplitView {
            Table(viewModel.nodes, selection: Binding(
                get: { selectedNode?.id },
                set: { id in selectedNode = viewModel.nodes.first { $0.id == id } }
            )) {
                TableColumn("Status") { node in
                    StatusBadge(status: node.isReady ? .healthy : .error)
                }
                .width(40)

                TableColumn("Name") { node in
                    Text(node.name)
                }
                .width(min: 150, ideal: 250)

                TableColumn("IP") { node in
                    Text(node.internalIP ?? "-")
                        .monospacedDigit()
                }
                .width(120)

                TableColumn("Version") { node in
                    Text(node.kubeletVersion ?? "-")
                }
                .width(100)

                TableColumn("OS") { node in
                    Text(node.osImage ?? "-")
                        .foregroundStyle(.secondary)
                }
                .width(min: 100, ideal: 150)

                TableColumn("Age") { node in
                    Text(formatAge(from: node.metadata.creationTimestamp))
                }
                .width(50)
            }
            .frame(minWidth: 400)

            if let node = selectedNode {
                NodeDetailPanel(node: node)
                    .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .navigationTitle("Nodes")
    }
}

struct NodeDetailPanel: View {
    let node: Node

    var body: some View {
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

    private func conditionStatus(type: String, value: String) -> StatusBadge.Status {
        // "Ready" should be True; other conditions (MemoryPressure, DiskPressure, etc.) should be False
        if type == "Ready" {
            return value == "True" ? .healthy : .error
        }
        return value == "False" ? .healthy : .warning
    }
}
