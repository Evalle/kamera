import SwiftUI

struct PodListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selectedPod: Pod?
    @State private var searchText = ""
    @State private var showLogs = false

    private var filteredPods: [Pod] {
        if searchText.isEmpty { return viewModel.pods }
        return viewModel.pods.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        HSplitView {
            // Pod list
            VStack(spacing: 0) {
                podTable
            }
            .frame(minWidth: 400)

            // Pod detail
            if let pod = selectedPod {
                PodDetailPanel(pod: pod, showLogs: $showLogs)
                    .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter pods...")
        .navigationTitle("Pods")
        .toolbar {
            ToolbarItem {
                Text("\(filteredPods.count) pods")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "Pod" else { return }
        if let match = viewModel.pods.first(where: { $0.name == pending.name }) {
            selectedPod = match
            viewModel.pendingSelection = nil
        }
    }

    private var podTable: some View {
        Table(filteredPods, selection: Binding(
            get: { selectedPod?.id },
            set: { id in selectedPod = filteredPods.first { $0.id == id } }
        )) {
            TableColumn("Status") { pod in
                StatusBadge(status: pod.statusBadge)
            }
            .width(40)

            if viewModel.isAllNamespaces {
                TableColumn("Namespace") { pod in
                    Text(pod.namespace ?? "-")
                }
                .width(100)
            }

            TableColumn("Name") { pod in
                Text(pod.name)
                    .fontWeight(pod.statusBadge == .error ? .medium : .regular)
            }
            .width(min: 150, ideal: 250)

            TableColumn("Ready") { pod in
                Text(pod.readyCount)
                    .monospacedDigit()
            }
            .width(50)

            TableColumn("Status") { pod in
                Text(pod.statusText)
                    .foregroundStyle(pod.statusBadge == .error ? .red : .primary)
            }
            .width(min: 80, ideal: 120)

            TableColumn("Restarts") { pod in
                Text("\(pod.totalRestarts)")
                    .monospacedDigit()
                    .foregroundStyle(pod.totalRestarts > 0 ? .orange : .primary)
            }
            .width(60)

            TableColumn("Age") { pod in
                Text(formatAge(from: pod.metadata.creationTimestamp))
            }
            .width(50)

            TableColumn("Node") { pod in
                Text(pod.spec?.nodeName ?? "-")
                    .foregroundStyle(.secondary)
            }
            .width(min: 80, ideal: 120)
        }
    }
}

// MARK: - Pod Detail Panel

struct PodDetailPanel: View {
    let pod: Pod
    @Binding var showLogs: Bool
    @State private var detailTab: DetailTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            DetailTabPicker(selection: $detailTab)
            if detailTab == .yaml {
                RawResourceView(resource: pod)
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header
                    HStack {
                        StatusBadge(status: pod.statusBadge)
                        Text(pod.name)
                            .font(.headline)
                        Spacer()
                        Button {
                            showLogs = true
                        } label: {
                            Label("Logs", systemImage: "text.alignleft")
                        }
                        .buttonStyle(.bordered)
                    }

                    Divider()

                    // Basic info
                    DetailSection(title: "Info") {
                        DetailRow(label: "Namespace", value: pod.namespace ?? "-")
                        DetailRow(label: "Node", value: pod.spec?.nodeName ?? "-")
                        DetailRow(label: "Pod IP", value: pod.status?.podIP ?? "-")
                        DetailRow(label: "Host IP", value: pod.status?.hostIP ?? "-")
                        DetailRow(label: "Restart Policy", value: pod.spec?.restartPolicy ?? "-")
                        DetailRow(label: "Age", value: formatAge(from: pod.metadata.creationTimestamp))
                    }

                    // Containers
                    if let containers = pod.spec?.containers {
                        DetailSection(title: "Containers") {
                            ForEach(containers) { container in
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(container.name)
                                        .fontWeight(.medium)
                                    Text(container.image ?? "unknown")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)

                                    if let status = pod.status?.containerStatuses?
                                        .first(where: { $0.name == container.name })
                                    {
                                        HStack(spacing: 4) {
                                            StatusBadge(status: status.ready ? .healthy : .warning)
                                            Text(status.ready ? "Ready" : "Not Ready")
                                                .font(.caption)
                                            if status.restartCount > 0 {
                                                Text("(\(status.restartCount) restarts)")
                                                    .font(.caption)
                                                    .foregroundStyle(.orange)
                                            }
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        }
                    }

                    // Owner References
                    if let owners = pod.metadata.ownerReferences, !owners.isEmpty {
                        DetailSection(title: "Owner References") {
                            ForEach(owners, id: \.uid) { owner in
                                HStack {
                                    Text(owner.kind)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 100, alignment: .leading)
                                    ResourceLink(kind: owner.kind, name: owner.name)
                                    Spacer()
                                }
                                .font(.callout)
                            }
                        }
                    }

                    // Related Events
                    RelatedEventsSection(resourceKind: "Pod", resourceName: pod.name)

                    // Labels
                    if let labels = pod.metadata.labels, !labels.isEmpty {
                        DetailSection(title: "Labels") {
                            FlowLayout(spacing: 4) {
                                ForEach(labels.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                                    Text("\(key)=\(value)")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(.quaternary)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            }
        }
        .sheet(isPresented: $showLogs) {
            LogStreamView(podName: pod.name, containers: pod.spec?.containers ?? [])
        }
    }
}

// MARK: - Reusable Detail Components

struct DetailSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            content
        }
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 100, alignment: .leading)
            Text(value)
            Spacer()
        }
        .font(.callout)
    }
}

// MARK: - Simple Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    private struct LayoutResult {
        var positions: [CGPoint]
        var sizes: [CGSize]
        var size: CGSize
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            sizes.append(size)

            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            totalHeight = y + rowHeight
        }

        return LayoutResult(
            positions: positions,
            sizes: sizes,
            size: CGSize(width: maxWidth, height: totalHeight)
        )
    }
}
