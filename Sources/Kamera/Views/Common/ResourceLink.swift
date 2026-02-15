import SwiftUI

struct ResourceLink: View {
    @Environment(ClusterViewModel.self) private var viewModel
    let kind: String
    let name: String

    var body: some View {
        if ClusterViewModel.ResourceKind.from(kubernetesKind: kind) != nil {
            Button {
                viewModel.navigateTo(kind: kind, name: name)
            } label: {
                HStack(spacing: 2) {
                    Text(name)
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption2)
                }
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)
            .help("Navigate to \(kind)/\(name)")
        } else {
            Text(name)
        }
    }
}
