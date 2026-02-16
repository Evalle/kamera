import SwiftUI

struct ConfigMapListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: ConfigMap?
    @State private var searchText = ""
    @State private var detailTab: DetailTab = .overview
    @State private var sortOrder = [KeyPathComparator(\ConfigMap.name)]

    private var filtered: [ConfigMap] {
        let base = searchText.isEmpty ? viewModel.configMaps : viewModel.configMaps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return base.sorted(using: sortOrder)
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            ), sortOrder: $sortOrder) {
                if viewModel.isAllNamespaces {
                    TableColumn("Namespace", sortUsing: KeyPathComparator(\.sortableNamespace)) { cm in
                        Text(cm.namespace ?? "-")
                    }.width(100)
                }
                TableColumn("Name", sortUsing: KeyPathComparator(\.name)) { cm in Text(cm.name) }.width(min: 150, ideal: 300)
                TableColumn("Data", sortUsing: KeyPathComparator(\.dataCount)) { cm in Text("\(cm.dataCount)").monospacedDigit() }.width(50)
                TableColumn("Age", sortUsing: KeyPathComparator(\.sortableAge)) { cm in Text(formatAge(from: cm.metadata.creationTimestamp)) }.width(50)
            }
            .frame(minWidth: 400)

            if let cm = selected {
                VStack(spacing: 0) {
                    DetailTabPicker(selection: $detailTab)
                    if detailTab == .yaml {
                        RawResourceView(resource: cm)
                    } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            Text(cm.name).font(.headline)
                            Divider()
                            DetailSection(title: "Info") {
                                DetailRow(label: "Namespace", value: cm.namespace ?? "-")
                                DetailRow(label: "Data Keys", value: "\(cm.dataCount)")
                                DetailRow(label: "Age", value: formatAge(from: cm.metadata.creationTimestamp))
                            }
                            if let data = cm.data, !data.isEmpty {
                                DetailSection(title: "Data") {
                                    ForEach(data.keys.sorted(), id: \.self) { key in
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(key).font(.callout).fontWeight(.medium)
                                            Text(data[key] ?? "")
                                                .font(.system(.caption, design: .monospaced))
                                                .foregroundStyle(.secondary)
                                                .lineLimit(5)
                                        }
                                        .padding(.vertical, 2)
                                    }
                                }
                            }
                            if let owners = cm.metadata.ownerReferences, !owners.isEmpty {
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
                            RelatedEventsSection(resourceKind: "ConfigMap", resourceName: cm.name)
                        }.padding()
                    }
                    }
                }
                .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter configmaps...")
        .navigationTitle("ConfigMaps")
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "ConfigMap" else { return }
        if let match = viewModel.configMaps.first(where: { $0.name == pending.name }) {
            selected = match
            viewModel.pendingSelection = nil
        }
    }
}
