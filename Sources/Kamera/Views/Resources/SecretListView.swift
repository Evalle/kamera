import SwiftUI

struct SecretListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: Secret?
    @State private var searchText = ""
    @State private var detailTab: DetailTab = .overview
    @State private var sortOrder = [KeyPathComparator(\Secret.name)]

    private var filtered: [Secret] {
        let base = searchText.isEmpty ? viewModel.secrets : viewModel.secrets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return base.sorted(using: sortOrder)
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            ), sortOrder: $sortOrder) {
                if viewModel.isAllNamespaces {
                    TableColumn("Namespace", sortUsing: KeyPathComparator(\.sortableNamespace)) { s in
                        Text(s.namespace ?? "-")
                    }.width(100)
                }
                TableColumn("Name", sortUsing: KeyPathComparator(\.name)) { s in Text(s.name) }.width(min: 150, ideal: 300)
                TableColumn("Type", sortUsing: KeyPathComparator(\.sortableType)) { s in Text(s.type ?? "-").foregroundStyle(.secondary) }.width(min: 100, ideal: 150)
                TableColumn("Data", sortUsing: KeyPathComparator(\.dataCount)) { s in Text("\(s.dataCount)").monospacedDigit() }.width(50)
                TableColumn("Age", sortUsing: KeyPathComparator(\.sortableAge)) { s in Text(formatAge(from: s.metadata.creationTimestamp)) }.width(50)
            }
            .frame(minWidth: 400)

            if let s = selected {
                VStack(spacing: 0) {
                    DetailTabPicker(selection: $detailTab)
                    if detailTab == .yaml {
                        RawResourceView(resource: s)
                    } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(s.name).font(.headline)
                            Divider()
                            DetailSection(title: "Info") {
                                DetailRow(label: "Namespace", value: s.namespace ?? "-")
                                DetailRow(label: "Type", value: s.type ?? "-")
                                DetailRow(label: "Data Keys", value: "\(s.dataCount)")
                                DetailRow(label: "Age", value: formatAge(from: s.metadata.creationTimestamp))
                            }
                            if let data = s.data, !data.isEmpty {
                                DetailSection(title: "Data Keys") {
                                    ForEach(data.keys.sorted(), id: \.self) { key in
                                        HStack {
                                            Text(key).font(.callout)
                                            Spacer()
                                            Text("\(data[key]?.count ?? 0) bytes")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                            if let owners = s.metadata.ownerReferences, !owners.isEmpty {
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
                            RelatedEventsSection(resourceKind: "Secret", resourceName: s.name)
                        }.padding()
                    }
                    }
                }
                .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter secrets...")
        .navigationTitle("Secrets")
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "Secret" else { return }
        if let match = viewModel.secrets.first(where: { $0.name == pending.name }) {
            selected = match
            viewModel.pendingSelection = nil
        }
    }
}
