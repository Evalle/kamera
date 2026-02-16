import SwiftUI

struct CronJobListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: CronJob?
    @State private var searchText = ""
    @State private var detailTab: DetailTab = .overview
    @State private var sortOrder = [KeyPathComparator(\CronJob.name)]

    private var filtered: [CronJob] {
        let base = searchText.isEmpty ? viewModel.cronJobs : viewModel.cronJobs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return base.sorted(using: sortOrder)
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            ), sortOrder: $sortOrder) {
                TableColumn("Status") { cj in
                    StatusBadge(status: cj.isSuspended ? .warning : .healthy)
                }.width(40)
                if viewModel.isAllNamespaces {
                    TableColumn("Namespace", sortUsing: KeyPathComparator(\.sortableNamespace)) { cj in
                        Text(cj.namespace ?? "-")
                    }.width(100)
                }
                TableColumn("Name", sortUsing: KeyPathComparator(\.name)) { cj in Text(cj.name) }.width(min: 150, ideal: 250)
                TableColumn("Schedule", sortUsing: KeyPathComparator(\.sortableSchedule)) { cj in Text(cj.spec?.schedule ?? "-").font(.system(.body, design: .monospaced)) }.width(min: 80, ideal: 120)
                TableColumn("Active", sortUsing: KeyPathComparator(\.activeCount)) { cj in Text("\(cj.activeCount)").monospacedDigit() }.width(50)
                TableColumn("Last Schedule") { cj in Text(formatAge(from: cj.status?.lastScheduleTime)) }.width(90)
                TableColumn("Age", sortUsing: KeyPathComparator(\.sortableAge)) { cj in Text(formatAge(from: cj.metadata.creationTimestamp)) }.width(50)
            }
            .frame(minWidth: 400)

            if let cj = selected {
                VStack(spacing: 0) {
                    DetailTabPicker(selection: $detailTab)
                    if detailTab == .yaml {
                        RawResourceView(resource: cj)
                    } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                StatusBadge(status: cj.isSuspended ? .warning : .healthy)
                                Text(cj.name).font(.headline)
                                if cj.isSuspended {
                                    Text("Suspended").font(.caption).padding(.horizontal, 6).padding(.vertical, 2).background(.orange.opacity(0.2)).clipShape(RoundedRectangle(cornerRadius: 4))
                                }
                            }
                            Divider()
                            DetailSection(title: "Info") {
                                DetailRow(label: "Namespace", value: cj.namespace ?? "-")
                                DetailRow(label: "Schedule", value: cj.spec?.schedule ?? "-")
                                DetailRow(label: "Concurrency", value: cj.spec?.concurrencyPolicy ?? "Allow")
                                DetailRow(label: "Suspended", value: cj.isSuspended ? "Yes" : "No")
                                DetailRow(label: "Active Jobs", value: "\(cj.activeCount)")
                                DetailRow(label: "Last Schedule", value: formatAge(from: cj.status?.lastScheduleTime))
                                DetailRow(label: "Age", value: formatAge(from: cj.metadata.creationTimestamp))
                            }
                            if let owners = cj.metadata.ownerReferences, !owners.isEmpty {
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
                            ResourceTreeSection(nodes: viewModel.relatedTreeForCronJob(cj))
                            RelatedEventsSection(resourceKind: "CronJob", resourceName: cj.name)
                        }.padding()
                    }
                    }
                }
                .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter cronjobs...")
        .navigationTitle("CronJobs")
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "CronJob" else { return }
        if let match = viewModel.cronJobs.first(where: { $0.name == pending.name }) {
            selected = match
            viewModel.pendingSelection = nil
        }
    }
}
