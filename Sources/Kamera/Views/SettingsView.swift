import SwiftUI

struct SettingsView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var showFileImporter = false

    private var resolvedDefault: String {
        KubeConfig.defaultConfigURL.path
    }

    var body: some View {
        Form {
            Section("Kubeconfig") {
                LabeledContent("Path") {
                    HStack {
                        Text(viewModel.kubeConfigPath.isEmpty ? resolvedDefault : viewModel.kubeConfigPath)
                            .foregroundStyle(viewModel.kubeConfigPath.isEmpty ? .secondary : .primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)

                        Button("Browse\u{2026}") {
                            showFileImporter = true
                        }

                        if !viewModel.kubeConfigPath.isEmpty {
                            Button("Reset to Default") {
                                viewModel.kubeConfigPath = ""
                                viewModel.loadConfig()
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 500)
        .fileImporter(
            isPresented: $showFileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            if case .success(let urls) = result, let url = urls.first {
                viewModel.kubeConfigPath = url.path
                viewModel.loadConfig()
            }
        }
    }
}
