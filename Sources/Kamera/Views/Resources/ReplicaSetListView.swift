import SwiftUI

struct ReplicaSetListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: ReplicaSet?
    @State private var searchText = ""

    private var filtered: [ReplicaSet] {
        if searchText.isEmpty { return viewModel.replicaSets }
        return viewModel.replicaSets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            )) {
                TableColumn("Status") { rs in
                    StatusBadge(status: rs.isReady ? .healthy : .warning)
                }.width(40)
                TableColumn("Name") { rs in Text(rs.name) }.width(min: 150, ideal: 250)
                TableColumn("Desired") { rs in Text("\(rs.spec?.replicas ?? 0)").monospacedDigit() }.width(60)
                TableColumn("Current") { rs in Text("\(rs.status?.replicas ?? 0)").monospacedDigit() }.width(60)
                TableColumn("Ready") { rs in Text("\(rs.status?.readyReplicas ?? 0)").monospacedDigit() }.width(50)
                TableColumn("Age") { rs in Text(formatAge(from: rs.metadata.creationTimestamp)) }.width(50)
            }
            .frame(minWidth: 400)

            if let rs = selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { StatusBadge(status: rs.isReady ? .healthy : .warning); Text(rs.name).font(.headline) }
                        Divider()
                        DetailSection(title: "Info") {
                            DetailRow(label: "Namespace", value: rs.namespace ?? "-")
                            DetailRow(label: "Replicas", value: rs.readyCount)
                            DetailRow(label: "Age", value: formatAge(from: rs.metadata.creationTimestamp))
                        }
                        if let owner = rs.metadata.ownerReferences?.first {
                            DetailSection(title: "Owner") {
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
                        RelatedEventsSection(resourceKind: "ReplicaSet", resourceName: rs.name)
                    }.padding()
                }.frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter replicasets...")
        .navigationTitle("ReplicaSets")
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "ReplicaSet" else { return }
        if let match = viewModel.replicaSets.first(where: { $0.name == pending.name }) {
            selected = match
            viewModel.pendingSelection = nil
        }
    }
}
