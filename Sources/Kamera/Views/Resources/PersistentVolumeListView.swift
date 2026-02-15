import SwiftUI

struct PersistentVolumeListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: PersistentVolume?
    @State private var searchText = ""

    private var filtered: [PersistentVolume] {
        if searchText.isEmpty { return viewModel.persistentVolumes }
        return viewModel.persistentVolumes.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            )) {
                TableColumn("Status") { pv in
                    StatusBadge(status: pv.statusBadge)
                }
                .width(40)

                TableColumn("Name") { pv in
                    Text(pv.name)
                }
                .width(min: 150, ideal: 200)

                TableColumn("Capacity") { pv in
                    Text(pv.capacity)
                        .monospacedDigit()
                }
                .width(70)

                TableColumn("Access Modes") { pv in
                    Text(pv.accessModesShort)
                }
                .width(80)

                TableColumn("Reclaim Policy") { pv in
                    Text(pv.spec?.persistentVolumeReclaimPolicy ?? "-")
                }
                .width(100)

                TableColumn("Phase") { pv in
                    Text(pv.status?.phase ?? "-")
                }
                .width(70)

                TableColumn("Storage Class") { pv in
                    Text(pv.spec?.storageClassName ?? "-")
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 120)

                TableColumn("Claim") { pv in
                    Text(pv.claimDescription)
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 150)

                TableColumn("Age") { pv in
                    Text(formatAge(from: pv.metadata.creationTimestamp))
                }
                .width(50)
            }
            .frame(minWidth: 400)

            if let pv = selected {
                PersistentVolumeDetailPanel(pv: pv)
                    .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter persistent volumes...")
        .navigationTitle("PersistentVolumes")
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "PersistentVolume" else { return }
        if let match = viewModel.persistentVolumes.first(where: { $0.name == pending.name }) {
            selected = match
            viewModel.pendingSelection = nil
        }
    }
}

struct PersistentVolumeDetailPanel: View {
    @Environment(ClusterViewModel.self) private var viewModel
    let pv: PersistentVolume

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    StatusBadge(status: pv.statusBadge)
                    Text(pv.name)
                        .font(.headline)
                }

                Divider()

                DetailSection(title: "Info") {
                    DetailRow(label: "Phase", value: pv.status?.phase ?? "-")
                    DetailRow(label: "Capacity", value: pv.capacity)
                    DetailRow(label: "Access Modes", value: pv.accessModesShort)
                    DetailRow(label: "Reclaim Policy", value: pv.spec?.persistentVolumeReclaimPolicy ?? "-")
                    DetailRow(label: "Storage Class", value: pv.spec?.storageClassName ?? "-")
                    DetailRow(label: "Age", value: formatAge(from: pv.metadata.creationTimestamp))
                }

                if let ref = pv.spec?.claimRef, let name = ref.name {
                    DetailSection(title: "Claim") {
                        HStack {
                            Text("PVC")
                                .foregroundStyle(.secondary)
                                .frame(width: 100, alignment: .leading)
                            ResourceLink(kind: "PersistentVolumeClaim", name: name)
                            Spacer()
                        }
                        .font(.callout)
                        if let ns = ref.namespace {
                            DetailRow(label: "Namespace", value: ns)
                        }
                    }
                }

                RelatedEventsSection(resourceKind: "PersistentVolume", resourceName: pv.name)
            }
            .padding()
        }
    }
}
