import Foundation
import SwiftUI

// MARK: - ClusterViewModel

@MainActor
@Observable
final class ClusterViewModel {
    // Connection state
    var kubeConfig: KubeConfig?
    var selectedContext: String?
    var selectedNamespace: String = "default"
    var availableNamespaces: [String] = ["default"]
    var isConnected = false
    var connectionError: String?

    // Resource data
    var pods: [Pod] = []
    var deployments: [Deployment] = []
    var services: [Service] = []
    var nodes: [Node] = []

    // UI state
    var selectedResource: ResourceKind = .pods
    var isLoading = false
    var resourceError: String?

    // Client
    private var client: KubernetesClient?
    private var watchTask: Task<Void, Never>?

    enum ResourceKind: String, CaseIterable, Identifiable {
        case pods = "Pods"
        case deployments = "Deployments"
        case services = "Services"
        case nodes = "Nodes"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .pods: return "cube"
            case .deployments: return "arrow.triangle.2.circlepath"
            case .services: return "network"
            case .nodes: return "server.rack"
            }
        }
    }

    // MARK: - Load KubeConfig

    func loadConfig() {
        do {
            let config = try KubeConfig.load()
            self.kubeConfig = config
            self.connectionError = nil

            // Auto-select current context
            if let current = config.currentContext {
                selectContext(current)
            }
        } catch {
            self.connectionError = "Failed to load kubeconfig: \(error.localizedDescription)"
        }
    }

    // MARK: - Context Switching

    func selectContext(_ name: String) {
        guard let config = kubeConfig else { return }

        selectedContext = name
        selectedNamespace = config.namespace(forContext: name)

        // Create client for this context
        guard let cluster = config.cluster(forContext: name),
              let userInfo = config.user(forContext: name)
        else {
            connectionError = "Invalid context configuration for '\(name)'"
            isConnected = false
            return
        }

        let auth = AuthProvider(userInfo: userInfo)
        do {
            client = try KubernetesClient(cluster: cluster, authProvider: auth)
            isConnected = true
            connectionError = nil

            // Load namespaces and resources
            Task {
                await loadNamespaces()
                await refreshResources()
            }
        } catch {
            connectionError = "Failed to connect: \(error.localizedDescription)"
            isConnected = false
        }
    }

    // MARK: - Namespace Switching

    func selectNamespace(_ namespace: String) {
        selectedNamespace = namespace
        Task {
            await refreshResources()
        }
    }

    // MARK: - Fetch Resources

    func refreshResources() async {
        guard let client = client else { return }

        isLoading = true
        resourceError = nil

        do {
            // Fetch all resource types in parallel
            async let fetchedPods = client.list(Pod.self, namespace: selectedNamespace)
            async let fetchedDeployments = client.list(
                Deployment.self, namespace: selectedNamespace
            )
            async let fetchedServices = client.list(Service.self, namespace: selectedNamespace)
            async let fetchedNodes = client.list(Node.self)

            pods = try await fetchedPods
            deployments = try await fetchedDeployments
            services = try await fetchedServices
            nodes = try await fetchedNodes

            isLoading = false
        } catch {
            resourceError = error.localizedDescription
            isLoading = false
        }
    }

    // MARK: - Watch Pods

    func startWatchingPods() {
        guard let client = client else { return }

        watchTask?.cancel()
        watchTask = Task {
            do {
                for try await event in client.watch(Pod.self, namespace: selectedNamespace) {
                    await handlePodEvent(event)
                }
            } catch {
                if !Task.isCancelled {
                    resourceError = "Watch disconnected: \(error.localizedDescription)"
                }
            }
        }
    }

    func stopWatching() {
        watchTask?.cancel()
        watchTask = nil
    }

    private func handlePodEvent(_ event: WatchEvent<Pod>) async {
        switch event.type {
        case .added:
            if !pods.contains(where: { $0.id == event.object.id }) {
                pods.append(event.object)
            }
        case .modified:
            if let index = pods.firstIndex(where: { $0.id == event.object.id }) {
                pods[index] = event.object
            }
        case .deleted:
            pods.removeAll { $0.id == event.object.id }
        case .error:
            break
        }
    }

    // MARK: - Fetch Namespaces

    private func loadNamespaces() async {
        guard let client = client else { return }
        do {
            availableNamespaces = try await client.namespaces()
        } catch {
            // Fall back to just "default"
            availableNamespaces = ["default"]
        }
    }

    // MARK: - Pod Logs

    func podLogs(
        name: String,
        container: String? = nil,
        tailLines: Int = 100
    ) -> AsyncThrowingStream<String, Error> {
        guard let client = client else {
            return AsyncThrowingStream { $0.finish(throwing: KubernetesError.notConnected) }
        }
        return client.logs(
            podName: name,
            namespace: selectedNamespace,
            container: container,
            follow: true,
            tailLines: tailLines
        )
    }
}
