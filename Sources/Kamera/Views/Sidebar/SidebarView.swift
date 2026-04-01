import SwiftUI

struct SidebarView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @Environment(PortForwardManager.self) private var portForwardManager

    var body: some View {
        @Bindable var vm = viewModel

        VStack(spacing: 0) {
            // Context, namespace pickers & refresh controls
            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Context")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    contextPicker
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text("Namespace")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    namespacePicker
                }
                HStack(spacing: 4) {
                    Text("Refresh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button {
                        Task { await viewModel.refreshResources() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.borderless)
                    .help("Refresh resources")
                    .disabled(!viewModel.isConnected)

                    Picker("Auto-refresh", selection: Binding(
                        get: { viewModel.autoRefreshInterval },
                        set: { viewModel.setAutoRefreshInterval($0) }
                    )) {
                        ForEach(ClusterViewModel.AutoRefreshInterval.allCases) { interval in
                            Text(interval.label).tag(interval)
                        }
                    }
                    .labelsHidden()
                    .frame(width: 60)
                    .help("Auto-refresh interval")
                    .disabled(!viewModel.isConnected)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            Divider()

            List(selection: $vm.selectedResource) {
                Section("Workloads") {
                    sidebarItem(.pods, "Pods", viewModel.pods.count)
                    sidebarItem(.deployments, "Deployments", viewModel.deployments.count)
                    sidebarItem(.statefulSets, "StatefulSets", viewModel.statefulSets.count)
                    sidebarItem(.daemonSets, "DaemonSets", viewModel.daemonSets.count)
                    sidebarItem(.replicaSets, "ReplicaSets", viewModel.replicaSets.count)
                    sidebarItem(.jobs, "Jobs", viewModel.jobs.count)
                    sidebarItem(.cronJobs, "CronJobs", viewModel.cronJobs.count)
                }

                Section("Config") {
                    sidebarItem(.configMaps, "ConfigMaps", viewModel.configMaps.count)
                    sidebarItem(.secrets, "Secrets", viewModel.secrets.count)
                }

                Section("Storage") {
                    sidebarItem(.persistentVolumes, "PersistentVolumes", viewModel.persistentVolumes.count)
                    sidebarItem(.persistentVolumeClaims, "PVCs", viewModel.persistentVolumeClaims.count)
                }

                Section("Network") {
                    sidebarItem(.services, "Services", viewModel.services.count)
                    sidebarItem(.ingresses, "Ingresses", viewModel.ingresses.count)
                }

                Section("Cluster") {
                    sidebarItem(.nodes, "Nodes", viewModel.nodes.count)
                    sidebarItem(.events, "Events", viewModel.events.count)
                }

                Section("Local") {
                    sidebarItem(.portForwards, "Port Forwards", portForwardManager.forwards.count)
                }
            }
            .listStyle(.sidebar)
        } // end VStack
    }

    // MARK: - Sidebar Item

    private func sidebarItem(_ kind: ClusterViewModel.ResourceKind, _ title: String, _ count: Int) -> some View {
        NavigationLink(value: kind) {
            Label {
                HStack {
                    Text(title)
                    Spacer()
                    Text("\(count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } icon: {
                Image(systemName: kind.systemImage)
            }
        }
    }

    // MARK: - Context Picker

    private var contextPicker: some View {
        Picker("Context", selection: Binding(
            get: { viewModel.selectedContext ?? "" },
            set: { viewModel.connectToContext($0) }
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
            Text("All Namespaces").tag(ClusterViewModel.allNamespaces)
            Divider()
            ForEach(viewModel.availableNamespaces, id: \.self) { ns in
                Text(ns).tag(ns)
            }
        }
        .labelsHidden()
    }
}
