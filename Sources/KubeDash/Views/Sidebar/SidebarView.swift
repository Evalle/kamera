import SwiftUI

struct SidebarView: View {
    @Environment(ClusterViewModel.self) private var viewModel

    var body: some View {
        @Bindable var vm = viewModel

        List(selection: $vm.selectedResource) {
            // Context picker
            Section("Cluster") {
                contextPicker
                namespacePicker
            }

            // Resource navigation
            Section("Workloads") {
                NavigationLink(value: ClusterViewModel.ResourceKind.pods) {
                    Label {
                        HStack {
                            Text("Pods")
                            Spacer()
                            Text("\(viewModel.pods.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "cube")
                    }
                }

                NavigationLink(value: ClusterViewModel.ResourceKind.deployments) {
                    Label {
                        HStack {
                            Text("Deployments")
                            Spacer()
                            Text("\(viewModel.deployments.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "arrow.triangle.2.circlepath")
                    }
                }

                NavigationLink(value: ClusterViewModel.ResourceKind.services) {
                    Label {
                        HStack {
                            Text("Services")
                            Spacer()
                            Text("\(viewModel.services.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "network")
                    }
                }
            }

            Section("Cluster") {
                NavigationLink(value: ClusterViewModel.ResourceKind.nodes) {
                    Label {
                        HStack {
                            Text("Nodes")
                            Spacer()
                            Text("\(viewModel.nodes.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "server.rack")
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .toolbar {
            ToolbarItem(placement: .automatic) {
                Button {
                    Task { await viewModel.refreshResources() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh resources")
                .disabled(!viewModel.isConnected)
            }
        }
    }

    // MARK: - Context Picker

    private var contextPicker: some View {
        Picker("Context", selection: Binding(
            get: { viewModel.selectedContext ?? "" },
            set: { viewModel.selectContext($0) }
        )) {
            if let contexts = viewModel.kubeConfig?.contexts {
                ForEach(contexts) { ctx in
                    Text(ctx.name)
                        .tag(ctx.name)
                }
            }
        }
        .labelsHidden()
    }

    // MARK: - Namespace Picker

    private var namespacePicker: some View {
        Picker("Namespace", selection: Binding(
            get: { viewModel.selectedNamespace },
            set: { viewModel.selectNamespace($0) }
        )) {
            ForEach(viewModel.availableNamespaces, id: \.self) { ns in
                Text(ns).tag(ns)
            }
        }
        .labelsHidden()
    }
}
