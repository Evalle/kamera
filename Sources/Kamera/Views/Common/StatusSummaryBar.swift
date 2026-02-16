import SwiftUI

struct StatusSummaryBar: View {
    @Environment(ClusterViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: 12) {
                chip(
                    icon: "server.rack",
                    label: "Nodes",
                    count: viewModel.unreadyNodeCount,
                    kind: .nodes
                )
                chip(
                    icon: "cube",
                    label: "Pods",
                    count: viewModel.unhealthyPodCount,
                    kind: .pods
                )
                chip(
                    icon: "arrow.triangle.2.circlepath",
                    label: "Deployments",
                    count: viewModel.unavailableDeploymentCount,
                    kind: .deployments
                )
                chip(
                    icon: "gearshape",
                    label: "Jobs",
                    count: viewModel.failedJobCount,
                    kind: .jobs
                )
                chip(
                    icon: "exclamationmark.bubble",
                    label: "Events",
                    count: viewModel.warningEventCount,
                    kind: .events
                )

                Spacer()

                if let ctx = viewModel.selectedContext {
                    HStack(spacing: 6) {
                        Text(ctx)
                            .foregroundStyle(.secondary)
                        Text("|")
                            .foregroundStyle(.quaternary)
                        Text(viewModel.isAllNamespaces ? "all namespaces" : viewModel.selectedNamespace)
                            .foregroundStyle(.secondary)
                    }
                    .font(.caption)
                    .lineLimit(1)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 4)
            .background(.bar)
        }
    }

    private func chip(
        icon: String,
        label: String,
        count: Int,
        kind: ClusterViewModel.ResourceKind
    ) -> some View {
        Button {
            viewModel.selectedResource = kind
        } label: {
            HStack(spacing: 3) {
                Image(systemName: icon)
                if count > 0 {
                    Text("\(count)")
                        .monospacedDigit()
                }
                Text(label)
            }
            .font(.caption)
            .foregroundStyle(count > 0 ? chipColor(for: kind, count: count) : .green)
        }
        .buttonStyle(.plain)
    }

    private func chipColor(for kind: ClusterViewModel.ResourceKind, count: Int) -> Color {
        switch kind {
        case .events: return .orange
        default: return .red
        }
    }
}
