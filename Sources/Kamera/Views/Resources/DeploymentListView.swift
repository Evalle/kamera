import SwiftUI

struct DeploymentListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selectedDeployment: Deployment?
    @State private var searchText = ""

    private var filtered: [Deployment] {
        if searchText.isEmpty { return viewModel.deployments }
        return viewModel.deployments.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selectedDeployment?.id },
                set: { id in selectedDeployment = filtered.first { $0.id == id } }
            )) {
                TableColumn("Status") { dep in
                    StatusBadge(status: dep.isAvailable ? .healthy : .warning)
                }
                .width(40)

                TableColumn("Name") { dep in
                    Text(dep.name)
                }
                .width(min: 150, ideal: 250)

                TableColumn("Ready") { dep in
                    Text(dep.readyCount)
                        .monospacedDigit()
                }
                .width(60)

                TableColumn("Up-to-date") { dep in
                    Text("\(dep.status?.updatedReplicas ?? 0)")
                        .monospacedDigit()
                }
                .width(80)

                TableColumn("Available") { dep in
                    Text("\(dep.status?.availableReplicas ?? 0)")
                        .monospacedDigit()
                }
                .width(70)

                TableColumn("Age") { dep in
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
    }
}

struct DeploymentDetailPanel: View {
    let deployment: Deployment

    var body: some View {
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
