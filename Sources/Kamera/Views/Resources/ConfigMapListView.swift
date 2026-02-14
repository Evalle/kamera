import SwiftUI

struct ConfigMapListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: ConfigMap?
    @State private var searchText = ""

    private var filtered: [ConfigMap] {
        if searchText.isEmpty { return viewModel.configMaps }
        return viewModel.configMaps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            )) {
                TableColumn("Name") { cm in Text(cm.name) }.width(min: 150, ideal: 300)
                TableColumn("Data") { cm in Text("\(cm.dataCount)").monospacedDigit() }.width(50)
                TableColumn("Age") { cm in Text(formatAge(from: cm.metadata.creationTimestamp)) }.width(50)
            }
            .frame(minWidth: 400)

            if let cm = selected {
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
                    }.padding()
                }.frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter configmaps...")
        .navigationTitle("ConfigMaps")
    }
}
