import SwiftUI

struct ContentView: View {
    @Environment(ClusterViewModel.self) private var viewModel

    var body: some View {
        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 180, ideal: 220, max: 280)
        } detail: {
            if viewModel.isConnected {
                ResourceDetailView()
            } else {
                NotConnectedView()
            }
        }
        .overlay {
            if viewModel.isQuickSearchPresented {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        viewModel.isQuickSearchPresented = false
                    }
                VStack {
                    QuickSearchView()
                        .padding(.top, 80)
                    Spacer()
                }
            }
        }
        .task {
            viewModel.loadConfig()
        }
    }
}

// MARK: - Resource Detail Router

struct ResourceDetailView: View {
    @Environment(ClusterViewModel.self) private var viewModel

    var body: some View {
        Group {
            switch viewModel.selectedResource {
            case .pods: PodListView()
            case .deployments: DeploymentListView()
            case .statefulSets: StatefulSetListView()
            case .daemonSets: DaemonSetListView()
            case .replicaSets: ReplicaSetListView()
            case .jobs: JobListView()
            case .cronJobs: CronJobListView()
            case .services: ServiceListView()
            case .ingresses: IngressListView()
            case .configMaps: ConfigMapListView()
            case .secrets: SecretListView()
            case .persistentVolumes: PersistentVolumeListView()
            case .persistentVolumeClaims: PersistentVolumeClaimListView()
            case .nodes: NodeListView()
            case .events: EventListView()
            }
        }
        .overlay {
            if viewModel.isLoading {
                ProgressView()
                    .controlSize(.large)
            }
        }
        .overlay(alignment: .top) {
            if let error = viewModel.resourceError {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.white)
                    Text(error)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                        .font(.callout)
                    Spacer()
                    Button("Retry") {
                        Task { await viewModel.refreshResources() }
                    }
                    .buttonStyle(.bordered)
                    .tint(.white)
                    Button {
                        viewModel.resourceError = nil
                    } label: {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                    .buttonStyle(.plain)
                }
                .padding(10)
                .background(Color.red.opacity(0.85), in: RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 12)
                .padding(.top, 8)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.resourceError)
    }
}

// MARK: - Not Connected Placeholder

struct NotConnectedView: View {
    @Environment(ClusterViewModel.self) private var viewModel

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "xmark.icloud")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Not Connected")
                .font(.title2)
                .fontWeight(.medium)

            if let error = viewModel.connectionError {
                Text(error)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            } else {
                Text("Select a context from the sidebar to connect to a cluster.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            Button("Reload Config") {
                viewModel.loadConfig()
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
