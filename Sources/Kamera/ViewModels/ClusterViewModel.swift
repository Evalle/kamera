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
    var statefulSets: [StatefulSet] = []
    var daemonSets: [DaemonSet] = []
    var replicaSets: [ReplicaSet] = []
    var jobs: [Job] = []
    var cronJobs: [CronJob] = []
    var services: [Service] = []
    var ingresses: [Ingress] = []
    var configMaps: [ConfigMap] = []
    var secrets: [Secret] = []
    var nodes: [Node] = []
    var persistentVolumes: [PersistentVolume] = []
    var persistentVolumeClaims: [PersistentVolumeClaim] = []
    var events: [Event] = []

    // UI state
    var selectedResource: ResourceKind = .pods
    var isLoading = false
    var resourceError: String?

    // Navigation
    var pendingSelection: PendingSelection?

    struct PendingSelection: Equatable {
        let kind: String
        let name: String
    }

    // Auto-refresh
    var autoRefreshInterval: AutoRefreshInterval = .thirtySeconds
    private var refreshTask: Task<Void, Never>?

    enum AutoRefreshInterval: Double, CaseIterable, Identifiable {
        case off = 0
        case fifteenSeconds = 15
        case thirtySeconds = 30
        case sixtySeconds = 60

        var id: Double { rawValue }

        var label: String {
            switch self {
            case .off: return "Off"
            case .fifteenSeconds: return "15s"
            case .thirtySeconds: return "30s"
            case .sixtySeconds: return "60s"
            }
        }
    }

    // Client
    private var client: KubernetesClient?
    private var watchTask: Task<Void, Never>?
    private var connectTask: Task<Void, Never>?

    enum ResourceKind: String, CaseIterable, Identifiable {
        case pods = "Pods"
        case deployments = "Deployments"
        case statefulSets = "StatefulSets"
        case daemonSets = "DaemonSets"
        case replicaSets = "ReplicaSets"
        case jobs = "Jobs"
        case cronJobs = "CronJobs"
        case services = "Services"
        case ingresses = "Ingresses"
        case configMaps = "ConfigMaps"
        case secrets = "Secrets"
        case persistentVolumes = "PersistentVolumes"
        case persistentVolumeClaims = "PersistentVolumeClaims"
        case nodes = "Nodes"
        case events = "Events"

        var id: String { rawValue }

        var systemImage: String {
            switch self {
            case .pods: return "cube"
            case .deployments: return "arrow.triangle.2.circlepath"
            case .statefulSets: return "square.stack.3d.up"
            case .daemonSets: return "circle.grid.3x3"
            case .replicaSets: return "square.on.square"
            case .jobs: return "gearshape"
            case .cronJobs: return "clock.arrow.2.circlepath"
            case .services: return "network"
            case .ingresses: return "arrow.right.arrow.left"
            case .configMaps: return "doc.text"
            case .secrets: return "lock"
            case .persistentVolumes: return "cylinder"
            case .persistentVolumeClaims: return "cylinder.split.1x2"
            case .nodes: return "server.rack"
            case .events: return "exclamationmark.bubble"
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
                connectToContext(current)
            }
        } catch {
            self.connectionError = "Failed to load kubeconfig: \(error.localizedDescription)"
        }
    }

    // MARK: - Context Switching

    func connectToContext(_ name: String) {
        guard let config = kubeConfig else { return }
        guard name != selectedContext || !isConnected else { return }

        // Cancel any previous connection setup
        connectTask?.cancel()
        watchTask?.cancel()
        refreshTask?.cancel()

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
            let newClient = try KubernetesClient(cluster: cluster, userInfo: userInfo, authProvider: auth)
            client = newClient
            isConnected = true
            connectionError = nil

            // Load namespaces and resources — capture client locally to avoid races
            connectTask = Task {
                await loadNamespaces(using: newClient)
                guard !Task.isCancelled else { return }
                await refreshResources(using: newClient)
                guard !Task.isCancelled else { return }
                startAutoRefresh()
            }
        } catch {
            connectionError = "Failed to connect: \(error.localizedDescription)"
            isConnected = false
        }
    }

    // MARK: - Namespace Switching

    func selectNamespace(_ namespace: String) {
        guard namespace != selectedNamespace else { return }
        selectedNamespace = namespace
        if let client = client {
            Task {
                await refreshResources(using: client)
                startAutoRefresh()
            }
        }
    }

    // MARK: - Fetch Resources

    func refreshResources() async {
        guard let client = client else { return }
        await refreshResources(using: client)
    }

    private func refreshResources(using client: KubernetesClient, silent: Bool = false) async {
        if !silent {
            isLoading = true
        }
        resourceError = nil

        let ns = selectedNamespace

        do {
            // Fetch all resource types in parallel
            async let fPods = client.list(Pod.self, namespace: ns)
            async let fDeployments = client.list(Deployment.self, namespace: ns)
            async let fStatefulSets = client.list(StatefulSet.self, namespace: ns)
            async let fDaemonSets = client.list(DaemonSet.self, namespace: ns)
            async let fReplicaSets = client.list(ReplicaSet.self, namespace: ns)
            async let fJobs = client.list(Job.self, namespace: ns)
            async let fCronJobs = client.list(CronJob.self, namespace: ns)
            async let fServices = client.list(Service.self, namespace: ns)
            async let fIngresses = client.list(Ingress.self, namespace: ns)
            async let fConfigMaps = client.list(ConfigMap.self, namespace: ns)
            async let fSecrets = client.list(Secret.self, namespace: ns)
            async let fNodes = client.list(Node.self)
            async let fPersistentVolumes = client.list(PersistentVolume.self)
            async let fPersistentVolumeClaims = client.list(PersistentVolumeClaim.self, namespace: ns)
            async let fEvents = client.list(Event.self, namespace: ns)

            let results = try await (
                fPods, fDeployments, fStatefulSets, fDaemonSets,
                fReplicaSets, fJobs, fCronJobs, fServices,
                fIngresses, fConfigMaps, fSecrets, fNodes,
                fPersistentVolumes, fPersistentVolumeClaims, fEvents
            )

            guard !Task.isCancelled else { return }

            pods = results.0
            deployments = results.1
            statefulSets = results.2
            daemonSets = results.3
            replicaSets = results.4
            jobs = results.5
            cronJobs = results.6
            services = results.7
            ingresses = results.8
            configMaps = results.9
            secrets = results.10
            nodes = results.11
            persistentVolumes = results.12
            persistentVolumeClaims = results.13
            events = results.14
            isLoading = false
        } catch {
            guard !Task.isCancelled else { return }
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

    private func loadNamespaces(using client: KubernetesClient) async {
        print("[Kamera] Loading namespaces...")

        // Try K8s API first
        do {
            let namespaces = try await client.namespaces()
            guard !Task.isCancelled else {
                print("[Kamera] Namespace fetch cancelled")
                return
            }
            print("[Kamera] K8s API returned \(namespaces.count) namespaces: \(namespaces)")
            availableNamespaces = namespaces.isEmpty ? ["default"] : namespaces
            if !availableNamespaces.contains(selectedNamespace) {
                selectedNamespace = availableNamespaces.first ?? "default"
            }
            return
        } catch {
            guard !Task.isCancelled else {
                print("[Kamera] Namespace fetch cancelled after error")
                return
            }
            print("[Kamera] K8s API namespace fetch failed: \(error)")
        }

        // Fallback: try kubectl
        print("[Kamera] Trying kubectl fallback...")
        let ctx = selectedContext
        let kubectlResult = await Task.detached {
            Self.fetchNamespacesViaKubectl(context: ctx)
        }.value
        print("[Kamera] kubectl returned \(kubectlResult.count) namespaces: \(kubectlResult)")

        if !kubectlResult.isEmpty {
            availableNamespaces = kubectlResult
        } else {
            let fallback = Set(["default", selectedNamespace])
            availableNamespaces = fallback.sorted()
        }

        if !availableNamespaces.contains(selectedNamespace) {
            selectedNamespace = availableNamespaces.first ?? "default"
        }
        print("[Kamera] Final namespace list: \(availableNamespaces)")
    }

    // Runs off MainActor to avoid blocking UI
    private nonisolated static func fetchNamespacesViaKubectl(context: String?) -> [String] {
        guard let context = context else { return [] }

        // Find kubectl path
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/bin/sh")
        whichProcess.arguments = ["-l", "-c", "which kubectl"]
        let whichPipe = Pipe()
        whichProcess.standardOutput = whichPipe
        whichProcess.standardError = Pipe()

        var kubectlPath = "/usr/local/bin/kubectl"
        do {
            try whichProcess.run()
            whichProcess.waitUntilExit()
            if whichProcess.terminationStatus == 0 {
                let data = whichPipe.fileHandleForReading.readDataToEndOfFile()
                if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !path.isEmpty {
                    kubectlPath = path
                }
            }
        } catch {}

        let process = Process()
        process.executableURL = URL(fileURLWithPath: kubectlPath)
        process.arguments = [
            "get", "namespaces",
            "--context", context,
            "-o", "jsonpath={.items[*].metadata.name}",
        ]
        let pipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = pipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? ""
                print("kubectl failed: \(errMsg)")
                return []
            }

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard let output = String(data: data, encoding: .utf8),
                  !output.isEmpty else { return [] }
            return output.split(separator: " ").map(String.init).sorted()
        } catch {
            print("kubectl exec failed: \(error)")
            return []
        }
    }

    // MARK: - Auto-Refresh

    func startAutoRefresh() {
        refreshTask?.cancel()
        guard autoRefreshInterval != .off, let client = client else { return }
        let interval = autoRefreshInterval.rawValue
        refreshTask = Task {
            while !Task.isCancelled && isConnected {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled && isConnected else { break }
                await refreshResources(using: client, silent: true)
            }
        }
    }

    func stopAutoRefresh() {
        refreshTask?.cancel()
        refreshTask = nil
    }

    func setAutoRefreshInterval(_ interval: AutoRefreshInterval) {
        autoRefreshInterval = interval
        startAutoRefresh()
    }

    // MARK: - Navigation

    func navigateTo(kind: String, name: String) {
        guard let resourceKind = ResourceKind.from(kubernetesKind: kind) else { return }
        selectedResource = resourceKind
        pendingSelection = PendingSelection(kind: kind, name: name)
    }

    // MARK: - Related Resources

    func childReplicaSets(ownedBy owner: ObjectMetadata) -> [ReplicaSet] {
        guard let uid = owner.uid else { return [] }
        return replicaSets.filter { rs in
            rs.metadata.ownerReferences?.contains { $0.uid == uid } ?? false
        }
    }

    func childPods(ownedBy owner: ObjectMetadata) -> [Pod] {
        guard let uid = owner.uid else { return [] }
        return pods.filter { pod in
            pod.metadata.ownerReferences?.contains { $0.uid == uid } ?? false
        }
    }

    func childJobs(ownedBy owner: ObjectMetadata) -> [Job] {
        guard let uid = owner.uid else { return [] }
        return jobs.filter { job in
            job.metadata.ownerReferences?.contains { $0.uid == uid } ?? false
        }
    }

    func podsOnNode(named nodeName: String) -> [Pod] {
        pods.filter { $0.spec?.nodeName == nodeName }
    }

    // MARK: - Tree Builders

    func relatedTreeForDeployment(_ deployment: Deployment) -> [ResourceTreeNode] {
        childReplicaSets(ownedBy: deployment.metadata).map { rs in
            ResourceTreeNode(
                id: rs.id,
                kind: "ReplicaSet",
                name: rs.name,
                status: rs.isReady ? .healthy : .warning,
                children: childPods(ownedBy: rs.metadata).map { podNode($0) }
            )
        }
    }

    func relatedTreeForCronJob(_ cronJob: CronJob) -> [ResourceTreeNode] {
        childJobs(ownedBy: cronJob.metadata).map { job in
            ResourceTreeNode(
                id: job.id,
                kind: "Job",
                name: job.name,
                status: job.isComplete ? .healthy : job.isFailed ? .error : .pending,
                children: childPods(ownedBy: job.metadata).map { podNode($0) }
            )
        }
    }

    func relatedTreeForStatefulSet(_ ss: StatefulSet) -> [ResourceTreeNode] {
        childPods(ownedBy: ss.metadata).map { podNode($0) }
    }

    func relatedTreeForDaemonSet(_ ds: DaemonSet) -> [ResourceTreeNode] {
        childPods(ownedBy: ds.metadata).map { podNode($0) }
    }

    func relatedTreeForReplicaSet(_ rs: ReplicaSet) -> [ResourceTreeNode] {
        childPods(ownedBy: rs.metadata).map { podNode($0) }
    }

    func relatedTreeForJob(_ job: Job) -> [ResourceTreeNode] {
        childPods(ownedBy: job.metadata).map { podNode($0) }
    }

    func relatedTreeForNode(_ node: Node) -> [ResourceTreeNode] {
        podsOnNode(named: node.name).map { podNode($0) }
    }

    private func podNode(_ pod: Pod) -> ResourceTreeNode {
        ResourceTreeNode(
            id: pod.id,
            kind: "Pod",
            name: pod.name,
            status: pod.statusBadge,
            children: []
        )
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
