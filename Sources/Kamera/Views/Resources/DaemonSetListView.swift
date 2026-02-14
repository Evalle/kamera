import SwiftUI

struct DaemonSetListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: DaemonSet?
    @State private var searchText = ""

    private var filtered: [DaemonSet] {
        if searchText.isEmpty { return viewModel.daemonSets }
        return viewModel.daemonSets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            )) {
                TableColumn("Status") { ds in
                    StatusBadge(status: ds.isReady ? .healthy : .warning)
                }.width(40)
                TableColumn("Name") { ds in Text(ds.name) }.width(min: 150, ideal: 250)
                TableColumn("Desired") { ds in Text("\(ds.status?.desiredNumberScheduled ?? 0)").monospacedDigit() }.width(60)
                TableColumn("Current") { ds in Text("\(ds.status?.currentNumberScheduled ?? 0)").monospacedDigit() }.width(60)
                TableColumn("Ready") { ds in Text("\(ds.status?.numberReady ?? 0)").monospacedDigit() }.width(50)
                TableColumn("Age") { ds in Text(formatAge(from: ds.metadata.creationTimestamp)) }.width(50)
            }
            .frame(minWidth: 400)

            if let ds = selected {
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
                    }.padding()
                }.frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter daemonsets...")
        .navigationTitle("DaemonSets")
    }
}
