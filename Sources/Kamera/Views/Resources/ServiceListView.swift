import SwiftUI

struct ServiceListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selectedService: Service?
    @State private var searchText = ""

    private var filtered: [Service] {
        if searchText.isEmpty { return viewModel.services }
        return viewModel.services.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selectedService?.id },
                set: { id in selectedService = filtered.first { $0.id == id } }
            )) {
                TableColumn("Name") { svc in
                    Text(svc.name)
                }
                .width(min: 150, ideal: 250)

                TableColumn("Type") { svc in
                    Text(svc.spec?.type ?? "-")
                        .foregroundStyle(.secondary)
                }
                .width(80)

                TableColumn("Cluster IP") { svc in
                    Text(svc.spec?.clusterIP ?? "-")
                        .monospacedDigit()
                }
                .width(120)

                TableColumn("Ports") { svc in
                    Text(formatPorts(svc.spec?.ports))
                        .monospacedDigit()
                }
                .width(min: 100, ideal: 150)

                TableColumn("Age") { svc in
                    Text(formatAge(from: svc.metadata.creationTimestamp))
                }
                .width(50)
            }
            .frame(minWidth: 400)

            if let svc = selectedService {
                ServiceDetailPanel(service: svc)
                    .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter services...")
        .navigationTitle("Services")
    }

    private func formatPorts(_ ports: [ServicePort]?) -> String {
        guard let ports = ports else { return "-" }
        return ports.map { p in
            let proto = p.protocol ?? "TCP"
            if let nodePort = p.nodePort {
                return "\(p.port):\(nodePort)/\(proto)"
            }
            return "\(p.port)/\(proto)"
        }.joined(separator: ", ")
    }
}

struct ServiceDetailPanel: View {
    let service: Service

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(service.name)
                    .font(.headline)

                Divider()

                DetailSection(title: "Info") {
                    DetailRow(label: "Namespace", value: service.namespace ?? "-")
                    DetailRow(label: "Type", value: service.spec?.type ?? "-")
                    DetailRow(label: "Cluster IP", value: service.spec?.clusterIP ?? "-")
                    if let lbIP = service.spec?.loadBalancerIP {
                        DetailRow(label: "LB IP", value: lbIP)
                    }
                    DetailRow(
                        label: "Age",
                        value: formatAge(from: service.metadata.creationTimestamp)
                    )
                }

                if let ports = service.spec?.ports, !ports.isEmpty {
                    DetailSection(title: "Ports") {
                        ForEach(ports) { port in
                            HStack {
                                Text(port.name ?? "unnamed")
                                    .frame(width: 80, alignment: .leading)
                                Text("\(port.port)")
                                    .monospacedDigit()
                                Image(systemName: "arrow.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Text(targetPortString(port.targetPort))
                                    .monospacedDigit()
                                Text(port.protocol ?? "TCP")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .font(.callout)
                        }
                    }
                }

                if let selector = service.spec?.selector, !selector.isEmpty {
                    DetailSection(title: "Selector") {
                        FlowLayout(spacing: 4) {
                            ForEach(
                                selector.sorted(by: { $0.key < $1.key }), id: \.key
                            ) { key, value in
                                Text("\(key)=\(value)")
                                    .font(.caption)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(.quaternary)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }

    private func targetPortString(_ targetPort: TargetPort?) -> String {
        guard let tp = targetPort else { return "-" }
        switch tp {
        case .int(let v): return "\(v)"
        case .string(let s): return s
        }
    }
}
