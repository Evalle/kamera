import SwiftUI

struct DaemonSetListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: DaemonSet?
    @State private var searchText = ""
    @State private var detailTab: DetailTab = .overview
    @State private var sortOrder = [KeyPathComparator(\DaemonSet.name)]

    private var filtered: [DaemonSet] {
        let base = searchText.isEmpty ? viewModel.daemonSets : viewModel.daemonSets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return base.sorted(using: sortOrder)
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            ), sortOrder: $sortOrder) {
                TableColumn("Status") { ds in
                    StatusBadge(status: ds.isReady ? .healthy : .warning)
                }.width(40)
                if viewModel.isAllNamespaces {
                    TableColumn("Namespace", sortUsing: KeyPathComparator(\.sortableNamespace)) { ds in
                        Text(ds.namespace ?? "-")
                    }.width(100)
                }
                TableColumn("Name", sortUsing: KeyPathComparator(\.name)) { ds in Text(ds.name) }.width(min: 150, ideal: 250)
                TableColumn("Desired", sortUsing: KeyPathComparator(\.sortableDesired)) { ds in Text("\(ds.status?.desiredNumberScheduled ?? 0)").monospacedDigit() }.width(60)
                TableColumn("Current") { ds in Text("\(ds.status?.currentNumberScheduled ?? 0)").monospacedDigit() }.width(60)
                TableColumn("Ready", sortUsing: KeyPathComparator(\.sortableReady)) { ds in Text("\(ds.status?.numberReady ?? 0)").monospacedDigit() }.width(50)
                TableColumn("Age", sortUsing: KeyPathComparator(\.sortableAge)) { ds in Text(formatAge(from: ds.metadata.creationTimestamp)) }.width(50)
            }
            .frame(minWidth: 400)

            if let ds = selected {
                VStack(spacing: 0) {
                    DetailTabPicker(selection: $detailTab)
                    if detailTab == .yaml {
                        RawResourceView(resource: ds)
                    } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack { StatusBadge(status: ds.isReady ? .healthy : .warning); Text(ds.name).font(.headline) }
                            Divider()
                            DetailSection(title: "Info") {
                                DetailRow(label: "Namespace", value: ds.namespace ?? "-")
                                DetailRow(label: "Desired", value: "\(ds.status?.desiredNumberScheduled ?? 0)")
                                DetailRow(label: "Current", value: "\(ds.status?.currentNumberScheduled ?? 0)")
                                DetailRow(label: "Ready", value: "\(ds.status?.numberReady ?? 0)")
                                DetailRow(label: "Available", value: "\(ds.status?.numberAvailable ?? 0)")
                                DetailRow(label: "Age", value: formatAge(from: ds.metadata.creationTimestamp))
                            }
                            if let owners = ds.metadata.ownerReferences, !owners.isEmpty {
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
                            ResourceTreeSection(nodes: viewModel.relatedTreeForDaemonSet(ds))
                            RelatedEventsSection(resourceKind: "DaemonSet", resourceName: ds.name)
                        }.padding()
                    }
                    }
                }
                .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter daemonsets...")
        .navigationTitle("DaemonSets")
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "DaemonSet" else { return }
        if let match = viewModel.daemonSets.first(where: { $0.name == pending.name }) {
            selected = match
            viewModel.pendingSelection = nil
        }
    }
}
