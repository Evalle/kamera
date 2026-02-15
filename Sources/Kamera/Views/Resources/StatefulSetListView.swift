import SwiftUI

struct StatefulSetListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: StatefulSet?
    @State private var searchText = ""

    private var filtered: [StatefulSet] {
        if searchText.isEmpty { return viewModel.statefulSets }
        return viewModel.statefulSets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            )) {
                TableColumn("Status") { ss in
                    StatusBadge(status: ss.isReady ? .healthy : .warning)
                }.width(40)
                TableColumn("Name") { ss in Text(ss.name) }.width(min: 150, ideal: 250)
                TableColumn("Ready") { ss in Text(ss.readyCount).monospacedDigit() }.width(60)
                TableColumn("Age") { ss in Text(formatAge(from: ss.metadata.creationTimestamp)) }.width(50)
            }
            .frame(minWidth: 400)

            if let ss = selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack { StatusBadge(status: ss.isReady ? .healthy : .warning); Text(ss.name).font(.headline) }
                        Divider()
                        DetailSection(title: "Info") {
                            DetailRow(label: "Namespace", value: ss.namespace ?? "-")
                            DetailRow(label: "Replicas", value: ss.readyCount)
                            DetailRow(label: "Service", value: ss.spec?.serviceName ?? "-")
                            DetailRow(label: "Age", value: formatAge(from: ss.metadata.creationTimestamp))
                        }
                        if let labels = ss.metadata.labels, !labels.isEmpty {
                            DetailSection(title: "Labels") {
                                FlowLayout(spacing: 4) {
                                    ForEach(labels.sorted(by: { $0.key < $1.key }), id: \.key) { k, v in
                                        Text("\(k)=\(v)").font(.caption).padding(.horizontal, 6).padding(.vertical, 2).background(.quaternary).clipShape(RoundedRectangle(cornerRadius: 4))
                                    }
                                }
                            }
                        }
                        if let owners = ss.metadata.ownerReferences, !owners.isEmpty {
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
                        ResourceTreeSection(nodes: viewModel.relatedTreeForStatefulSet(ss))
                        RelatedEventsSection(resourceKind: "StatefulSet", resourceName: ss.name)
                    }.padding()
                }.frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter statefulsets...")
        .navigationTitle("StatefulSets")
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "StatefulSet" else { return }
        if let match = viewModel.statefulSets.first(where: { $0.name == pending.name }) {
            selected = match
            viewModel.pendingSelection = nil
        }
    }
}
