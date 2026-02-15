import SwiftUI

struct PersistentVolumeClaimListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: PersistentVolumeClaim?
    @State private var searchText = ""

    private var filtered: [PersistentVolumeClaim] {
        if searchText.isEmpty { return viewModel.persistentVolumeClaims }
        return viewModel.persistentVolumeClaims.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            )) {
                TableColumn("Status") { pvc in
                    StatusBadge(status: pvc.statusBadge)
                }
                .width(40)

                if viewModel.isAllNamespaces {
                    TableColumn("Namespace") { pvc in
                        Text(pvc.namespace ?? "-")
                    }
                    .width(100)
                }

                TableColumn("Name") { pvc in
                    Text(pvc.name)
                }
                .width(min: 150, ideal: 200)

                TableColumn("Phase") { pvc in
                    Text(pvc.status?.phase ?? "-")
                }
                .width(70)

                TableColumn("Volume") { pvc in
                    Text(pvc.spec?.volumeName ?? "-")
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 150)

                TableColumn("Capacity") { pvc in
                    Text(pvc.actualCapacity)
                        .monospacedDigit()
                }
                .width(70)

                TableColumn("Access Modes") { pvc in
                    Text(pvc.accessModesShort)
                }
                .width(80)

                TableColumn("Storage Class") { pvc in
                    Text(pvc.spec?.storageClassName ?? "-")
                        .foregroundStyle(.secondary)
                }
                .width(min: 80, ideal: 120)

                TableColumn("Age") { pvc in
                    Text(formatAge(from: pvc.metadata.creationTimestamp))
                }
                .width(50)
            }
            .frame(minWidth: 400)

            if let pvc = selected {
                PersistentVolumeClaimDetailPanel(pvc: pvc)
                    .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter persistent volume claims...")
        .navigationTitle("PersistentVolumeClaims")
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "PersistentVolumeClaim" else { return }
        if let match = viewModel.persistentVolumeClaims.first(where: { $0.name == pending.name }) {
            selected = match
            viewModel.pendingSelection = nil
        }
    }
}

struct PersistentVolumeClaimDetailPanel: View {
    @Environment(ClusterViewModel.self) private var viewModel
    let pvc: PersistentVolumeClaim
    @State private var detailTab: DetailTab = .overview

    var body: some View {
        VStack(spacing: 0) {
            DetailTabPicker(selection: $detailTab)
            if detailTab == .yaml {
                RawResourceView(resource: pvc)
            } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        StatusBadge(status: pvc.statusBadge)
                        Text(pvc.name)
                            .font(.headline)
                    }

                    Divider()

                    DetailSection(title: "Info") {
                        DetailRow(label: "Namespace", value: pvc.namespace ?? "-")
                        DetailRow(label: "Phase", value: pvc.status?.phase ?? "-")
                        DetailRow(label: "Volume", value: pvc.spec?.volumeName ?? "-")
                        DetailRow(label: "Requested", value: pvc.requestedStorage)
                        DetailRow(label: "Capacity", value: pvc.actualCapacity)
                        DetailRow(label: "Access Modes", value: pvc.accessModesShort)
                        DetailRow(label: "Storage Class", value: pvc.spec?.storageClassName ?? "-")
                        DetailRow(label: "Age", value: formatAge(from: pvc.metadata.creationTimestamp))
                    }

                    if let owners = pvc.metadata.ownerReferences, !owners.isEmpty {
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

                    RelatedEventsSection(resourceKind: "PersistentVolumeClaim", resourceName: pvc.name)
                }
                .padding()
            }
            }
        }
    }
}
