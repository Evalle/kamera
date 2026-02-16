import SwiftUI

struct JobListView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var selected: Job?
    @State private var searchText = ""
    @State private var detailTab: DetailTab = .overview
    @State private var sortOrder = [KeyPathComparator(\Job.name)]

    private var filtered: [Job] {
        let base = searchText.isEmpty ? viewModel.jobs : viewModel.jobs.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        return base.sorted(using: sortOrder)
    }

    var body: some View {
        HSplitView {
            Table(filtered, selection: Binding(
                get: { selected?.id },
                set: { id in selected = filtered.first { $0.id == id } }
            ), sortOrder: $sortOrder) {
                TableColumn("Status") { job in
                    StatusBadge(status: job.isComplete ? .healthy : job.isFailed ? .error : .pending)
                }.width(40)
                if viewModel.isAllNamespaces {
                    TableColumn("Namespace", sortUsing: KeyPathComparator(\.sortableNamespace)) { job in
                        Text(job.namespace ?? "-")
                    }.width(100)
                }
                TableColumn("Name", sortUsing: KeyPathComparator(\.name)) { job in Text(job.name) }.width(min: 150, ideal: 250)
                TableColumn("Completions", sortUsing: KeyPathComparator(\.sortableSucceeded)) { job in Text(job.completionCount).monospacedDigit() }.width(80)
                TableColumn("Duration") { job in Text(job.duration).monospacedDigit() }.width(70)
                TableColumn("Age", sortUsing: KeyPathComparator(\.sortableAge)) { job in Text(formatAge(from: job.metadata.creationTimestamp)) }.width(50)
            }
            .frame(minWidth: 400)

            if let job = selected {
                VStack(spacing: 0) {
                    DetailTabPicker(selection: $detailTab)
                    if detailTab == .yaml {
                        RawResourceView(resource: job)
                    } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                StatusBadge(status: job.isComplete ? .healthy : job.isFailed ? .error : .pending)
                                Text(job.name).font(.headline)
                            }
                            Divider()
                            DetailSection(title: "Info") {
                                DetailRow(label: "Namespace", value: job.namespace ?? "-")
                                DetailRow(label: "Completions", value: job.completionCount)
                                DetailRow(label: "Parallelism", value: "\(job.spec?.parallelism ?? 1)")
                                DetailRow(label: "Backoff Limit", value: "\(job.spec?.backoffLimit ?? 6)")
                                DetailRow(label: "Duration", value: job.duration)
                                DetailRow(label: "Age", value: formatAge(from: job.metadata.creationTimestamp))
                            }
                            if let conditions = job.status?.conditions, !conditions.isEmpty {
                                DetailSection(title: "Conditions") {
                                    ForEach(conditions, id: \.type) { cond in
                                        HStack {
                                            StatusBadge(status: cond.type == "Complete" ? .healthy : .error)
                                            VStack(alignment: .leading) {
                                                Text(cond.type).font(.callout)
                                                if let msg = cond.message { Text(msg).font(.caption).foregroundStyle(.secondary) }
                                            }
                                        }
                                    }
                                }
                            }
                            if let owners = job.metadata.ownerReferences, !owners.isEmpty {
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
                            ResourceTreeSection(nodes: viewModel.relatedTreeForJob(job))
                            RelatedEventsSection(resourceKind: "Job", resourceName: job.name)
                        }.padding()
                    }
                    }
                }
                .frame(minWidth: 300, idealWidth: 350)
            }
        }
        .searchable(text: $searchText, prompt: "Filter jobs...")
        .navigationTitle("Jobs")
        .onAppear { handlePendingSelection() }
        .onChange(of: viewModel.pendingSelection) { handlePendingSelection() }
    }

    private func handlePendingSelection() {
        guard let pending = viewModel.pendingSelection, pending.kind == "Job" else { return }
        if let match = viewModel.jobs.first(where: { $0.name == pending.name }) {
            selected = match
            viewModel.pendingSelection = nil
        }
    }
}
