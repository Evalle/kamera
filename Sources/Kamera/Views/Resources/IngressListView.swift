import SwiftUI

struct IngressListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: Ingress?
    @State private var searchText = ""

    private var filtered: [Ingress] {
        if searchText.isEmpty { return viewModel.ingresses }
        return viewModel.ingresses.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            )) {
                TableColumn("Name") { ing in Text(ing.name) }.width(min: 150, ideal: 200)
                TableColumn("Class") { ing in Text(ing.spec?.ingressClassName ?? "-").foregroundStyle(.secondary) }.width(80)
                TableColumn("Hosts") { ing in Text(ing.hosts.joined(separator: ", ")).lineLimit(1) }.width(min: 100, ideal: 200)
                TableColumn("Address") { ing in Text(ing.addresses.joined(separator: ", ")).monospacedDigit() }.width(min: 80, ideal: 120)
                TableColumn("TLS") { ing in Text(ing.hasTLS ? "Yes" : "No") }.width(40)
                TableColumn("Age") { ing in Text(formatAge(from: ing.metadata.creationTimestamp)) }.width(50)
            }
            .frame(minWidth: 400)

            if let ing = selected {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(ing.name).font(.headline)
                        Divider()
                        DetailSection(title: "Info") {
                            DetailRow(label: "Namespace", value: ing.namespace ?? "-")
                            DetailRow(label: "Class", value: ing.spec?.ingressClassName ?? "-")
                            DetailRow(label: "Address", value: ing.addresses.joined(separator: ", ").isEmpty ? "-" : ing.addresses.joined(separator: ", "))
                            DetailRow(label: "TLS", value: ing.hasTLS ? "Yes" : "No")
                            DetailRow(label: "Age", value: formatAge(from: ing.metadata.creationTimestamp))
                        }
                        if let rules = ing.spec?.rules, !rules.isEmpty {
                            DetailSection(title: "Rules") {
                                ForEach(Array(rules.enumerated()), id: \.offset) { _, rule in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(rule.host ?? "*").font(.callout).fontWeight(.medium)
                                        if let paths = rule.http?.paths {
                                            ForEach(Array(paths.enumerated()), id: \.offset) { _, path in
                                                HStack {
                                                    Text(path.path ?? "/").font(.system(.caption, design: .monospaced))
                                                    Image(systemName: "arrow.right").font(.caption2).foregroundStyle(.secondary)
                                                    Text("\(path.backend?.service?.name ?? "?"):\(path.backend?.service?.port?.number.map(String.init) ?? path.backend?.service?.port?.name ?? "?")")
                                                        .font(.caption)
                                                    Text(path.pathType ?? "").font(.caption2).foregroundStyle(.secondary)
                                                }
                                            }
                                        }
                                    }.padding(.vertical, 2)
                                }
                            }
                        }
                    }.padding()
                }.frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter ingresses...")
        .navigationTitle("Ingresses")
    }
}
