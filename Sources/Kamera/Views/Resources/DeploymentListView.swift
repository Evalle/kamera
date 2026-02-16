import SwiftUI

struct DeploymentListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selectedDeployment: Deployment?
    @State private var searchText = ""
    @State private var sortOrder = [KeyPathComparator(\Deployment.name)]

    private var filtered: [Deployment] {
        let base = searchText.isEmpty ? viewModel.deployments : viewModel.deployments.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
        return base.sorted(using: sortOrder)
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selectedDeployment?.id },
                set: { id in selectedDeployment = filtered.first { $0.id == id } }
            ), sortOrder: $sortOrder) {
                TableColumn("Status") { dep in
                    StatusBadge(status: dep.isAvailable ? .healthy : .warning)
                }
                .width(40)

                if viewModel.isAllNamespaces {
                    TableColumn("Namespace", sortUsing: KeyPathComparator(\.sortableNamespace)) { dep in
                        Text(dep.namespace ?? "-")
                    }
                    .width(100)
                }

                TableColumn("Name", sortUsing: KeyPathComparator(\.name)) { dep in
                    Text(dep.name)
                }
                .width(min: 150, ideal: 250)

                TableColumn("Ready", sortUsing: KeyPathComparator(\.sortableReady)) { dep in
                    Text(dep.readyCount)
                        .monospacedDigit()
                }
                .width(60)

                TableColumn("Up-to-date") { dep in
                    Text("\(dep.status?.updatedReplicas ?? 0)")
                        .monospacedDigit()
                }
                .width(80)

                TableColumn("Available", sortUsing: KeyPathComparator(\.sortableAvailable)) { dep in
                    Text("\(dep.status?.availableReplicas ?? 0)")
                        .monospacedDigit()
                }
                .width(70)

                TableColumn("Age", sortUsing: KeyPathComparator(\.sortableAge)) { dep in
                    Text(formatAge(from: dep.metadata.creationTimestamp))
                }
                .width(50)
            }
            .frame(minWidth: 400)

            if let dep = selectedDeployment {
                DeploymentDetailPanel(deployment: dep)
                    .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter deployments...")
        .navigationTitle("Deployments")
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "Deployment" else { return }
        if let match = viewModel.deployments.first(where: { $0.name == pending.name }) {
            selectedDeployment = match
            viewModel.pendingSelection = nil
        }
    }
}

struct DeploymentDetailPanel: View {
    @Environment(ClusterViewModel.self) private var viewModel
    let deployment: Deployment
    @State private var detailTab: DetailTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            DetailTabPicker(selection: $detailTab)
            if detailTab == .yaml {
                RawResourceView(resource: deployment)
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        StatusBadge(status: deployment.isAvailable ? .healthy : .warning)
                        Text(deployment.name)
                            .font(.headline)
                    }

                    Divider()

                    DetailSection(title: "Info") {
                        DetailRow(label: "Namespace", value: deployment.namespace ?? "-")
                        DetailRow(label: "Replicas", value: deployment.readyCount)
                        DetailRow(
                            label: "Age",
                            value: formatAge(from: deployment.metadata.creationTimestamp)
                        )
                    }

                    if let conditions = deployment.status?.conditions, !conditions.isEmpty {
                        DetailSection(title: "Conditions") {
                            ForEach(conditions, id: \.type) { cond in
                                HStack {
                                    StatusBadge(
                                        status: cond.status == "True" ? .healthy : .warning
                                    )
                                    VStack(alignment: .leading) {
                                        Text(cond.type)
                                            .font(.callout)
                                        if let msg = cond.message {
                                            Text(msg)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    ResourceTreeSection(nodes: viewModel.relatedTreeForDeployment(deployment))

                    RelatedEventsSection(resourceKind: "Deployment", resourceName: deployment.name)

                    if let selector = deployment.spec?.selector?.matchLabels, !selector.isEmpty {
                        DetailSection(title: "Selector") {
                            FlowLayout(spacing: 4) {
                                ForEach(
                                    selector.sorted(by: { $0.key < $1.key }), id: \.key
                                ) { key, value in
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
    }
}
