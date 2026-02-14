import SwiftUI

struct SecretListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: Secret?
    @State private var searchText = ""

    private var filtered: [Secret] {
        if searchText.isEmpty { return viewModel.secrets }
        return viewModel.secrets.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            )) {
                TableColumn("Name") { s in Text(s.name) }.width(min: 150, ideal: 300)
                TableColumn("Type") { s in Text(s.type ?? "-").foregroundStyle(.secondary) }.width(min: 100, ideal: 150)
                TableColumn("Data") { s in Text("\(s.dataCount)").monospacedDigit() }.width(50)
                TableColumn("Age") { s in Text(formatAge(from: s.metadata.creationTimestamp)) }.width(50)
            }
            .frame(minWidth: 400)

            if let s = selected {
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
                    }.padding()
                }.frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter secrets...")
        .navigationTitle("Secrets")
    }
}
