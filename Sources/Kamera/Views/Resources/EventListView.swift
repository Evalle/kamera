import SwiftUI

struct EventListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: Event?
    @State private var searchText = ""

    private var filtered: [Event] {
        if searchText.isEmpty { return viewModel.events }
        return viewModel.events.filter {
            ($0.reason ?? "").localizedCaseInsensitiveContains(searchText)
                || ($0.message ?? "").localizedCaseInsensitiveContains(searchText)
                || ($0.involvedObject?.name ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            )) {
                TableColumn("Type") { event in
                    Image(systemName: event.isWarning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                        .foregroundStyle(event.isWarning ? .orange : .blue)
                        .font(.caption)
                }.width(30)
                if viewModel.isAllNamespaces {
                    TableColumn("Namespace") { event in
                        Text(event.namespace ?? "-")
                    }.width(100)
                }
                TableColumn("Reason") { event in
                    Text(event.reason ?? "-")
                }.width(min: 80, ideal: 120)
                TableColumn("Object") { event in
                    if let obj = event.involvedObject, let kind = obj.kind, let name = obj.name {
                        HStack(spacing: 2) {
                            Text("\(kind)/")
                                .foregroundStyle(.secondary)
                            ResourceLink(kind: kind, name: name)
                        }
                    } else {
                        Text(event.involvedObjectDescription)
                    }
                }.width(min: 100, ideal: 180)
                TableColumn("Message") { event in
                    Text(event.message ?? "-")
                        .lineLimit(1)
                }.width(min: 150, ideal: 300)
                TableColumn("Count") { event in
                    Text("\(event.count ?? 1)")
                        .monospacedDigit()
                }.width(40)
                TableColumn("Age") { event in
                    Text(event.age)
                }.width(50)
            }
            .frame(minWidth: 500)

            if let event = selected {
                TabView {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack(spacing: 8) {
                                Image(systemName: event.isWarning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                                    .foregroundStyle(event.isWarning ? .orange : .blue)
                                Text(event.reason ?? event.name)
                                    .font(.headline)
                            }
                            Divider()
                            DetailSection(title: "Event Info") {
                                DetailRow(label: "Type", value: event.type ?? "-")
                                DetailRow(label: "Reason", value: event.reason ?? "-")
                                DetailRow(label: "Count", value: "\(event.count ?? 1)")
                                DetailRow(label: "First Seen", value: formatAge(from: event.firstTimestamp))
                                DetailRow(label: "Last Seen", value: formatAge(from: event.lastTimestamp))
                            }
                            if let obj = event.involvedObject {
                                DetailSection(title: "Involved Object") {
                                    DetailRow(label: "Kind", value: obj.kind ?? "-")
                                    HStack {
                                        Text("Name")
                                            .foregroundStyle(.secondary)
                                            .frame(width: 100, alignment: .leading)
                                        if let kind = obj.kind, let name = obj.name {
                                            ResourceLink(kind: kind, name: name)
                                        } else {
                                            Text(obj.name ?? "-")
                                        }
                                        Spacer()
                                    }
                                    .font(.callout)
                                    DetailRow(label: "Namespace", value: obj.namespace ?? "-")
                                }
                            }
                            if let source = event.source {
                                DetailSection(title: "Source") {
                                    DetailRow(label: "Component", value: source.component ?? "-")
                                    DetailRow(label: "Host", value: source.host ?? "-")
                                }
                            }
                            if let message = event.message, !message.isEmpty {
                                DetailSection(title: "Message") {
                                    Text(message)
                                        .font(.system(.callout, design: .monospaced))
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                }
                            }
                        }.padding()
                    }
                    .tabItem { Label("Overview", systemImage: "list.bullet") }

                    RawResourceView(resource: event)
                        .tabItem { Label("YAML", systemImage: "doc.text") }
                }
                .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter events...")
        .navigationTitle("Events")
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "Event" else { return }
        if let match = viewModel.events.first(where: { $0.name == pending.name }) {
            selected = match
            viewModel.pendingSelection = nil
        }
    }
}
