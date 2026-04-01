import XCTest
@testable import Kamera

@MainActor
final class ClusterViewModelTests: XCTestCase {

    // MARK: - Health Summary Tests

    func testUnhealthyPodCountZero() {
        let vm = ClusterViewModel()
        vm.pods = [
            makePod(name: "healthy-1", uid: "h1", phase: "Running", readyContainers: 1),
            makePod(name: "healthy-2", uid: "h2", phase: "Succeeded"),
        ]
        XCTAssertEqual(vm.unhealthyPodCount, 0)
    }

    func testUnhealthyPodCountMixed() {
        let vm = ClusterViewModel()
        vm.pods = [
            makePod(name: "healthy", uid: "h1", phase: "Running", readyContainers: 1),
            makePod(name: "warning", uid: "w1", phase: "Running", containerCount: 1, readyContainers: 0),
            makePod(name: "failed", uid: "f1", phase: "Failed"),
        ]
        XCTAssertEqual(vm.unhealthyPodCount, 2)
    }

    func testUnavailableDeploymentCount() {
        let vm = ClusterViewModel()
        vm.deployments = [
            makeDeployment(name: "ok", uid: "d1", replicas: 3, availableReplicas: 3),
            makeDeployment(name: "bad", uid: "d2", replicas: 3, availableReplicas: 1),
        ]
        XCTAssertEqual(vm.unavailableDeploymentCount, 1)
    }

    func testFailedJobCount() {
        let vm = ClusterViewModel()
        vm.jobs = [
            makeJob(name: "complete", uid: "j1", isComplete: true),
            makeJob(name: "failed", uid: "j2", isFailed: true),
            makeJob(name: "running", uid: "j3"),
        ]
        XCTAssertEqual(vm.failedJobCount, 1)
    }

    func testUnreadyNodeCount() {
        let vm = ClusterViewModel()
        vm.nodes = [
            makeNode(name: "ready", uid: "n1", isReady: true),
            makeNode(name: "unready", uid: "n2", isReady: false),
        ]
        XCTAssertEqual(vm.unreadyNodeCount, 1)
    }

    func testWarningEventCount() {
        let vm = ClusterViewModel()
        vm.events = [
            makeEvent(name: "warn1", type: "Warning"),
            makeEvent(name: "norm1", type: "Normal"),
            makeEvent(name: "warn2", type: "Warning"),
        ]
        XCTAssertEqual(vm.warningEventCount, 2)
    }

    func testHealthCountsEmptyArrays() {
        let vm = ClusterViewModel()
        XCTAssertEqual(vm.unhealthyPodCount, 0)
        XCTAssertEqual(vm.unavailableDeploymentCount, 0)
        XCTAssertEqual(vm.failedJobCount, 0)
        XCTAssertEqual(vm.unreadyNodeCount, 0)
        XCTAssertEqual(vm.warningEventCount, 0)
    }

    // MARK: - Search Tests

    func testSearchFindsMatchingPods() {
        let vm = ClusterViewModel()
        vm.pods = [
            makePod(name: "nginx-abc", uid: "p1"),
            makePod(name: "redis-xyz", uid: "p2"),
        ]
        let results = vm.searchAllResources(query: "nginx")
        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.name, "nginx-abc")
    }

    func testSearchCaseInsensitive() {
        let vm = ClusterViewModel()
        vm.pods = [makePod(name: "nginx-pod", uid: "p1")]
        let results = vm.searchAllResources(query: "NGINX")
        XCTAssertEqual(results.count, 1)
    }

    func testSearchAcrossResourceTypes() {
        let vm = ClusterViewModel()
        vm.pods = [makePod(name: "app-pod", uid: "p1")]
        vm.deployments = [makeDeployment(name: "app-deploy", uid: "d1")]
        let results = vm.searchAllResources(query: "app")
        XCTAssertEqual(results.count, 2)
    }

    func testSearchEmptyQuery() {
        let vm = ClusterViewModel()
        vm.pods = [makePod(name: "nginx", uid: "p1")]
        let results = vm.searchAllResources(query: "")
        XCTAssertTrue(results.isEmpty)
    }

    func testSearchNoMatch() {
        let vm = ClusterViewModel()
        vm.pods = [makePod(name: "nginx", uid: "p1")]
        let results = vm.searchAllResources(query: "zzz-nonexistent")
        XCTAssertTrue(results.isEmpty)
    }

    // MARK: - Navigation Tests

    func testNavigateTo() {
        let vm = ClusterViewModel()
        vm.navigateTo(kind: "Deployment", name: "my-deploy")
        XCTAssertEqual(vm.selectedResource, .deployments)
        XCTAssertEqual(vm.pendingSelection, ClusterViewModel.PendingSelection(kind: "Deployment", name: "my-deploy"))
    }

    func testNavigateToInvalidKind() {
        let vm = ClusterViewModel()
        vm.selectedResource = .pods
        vm.navigateTo(kind: "UnknownKind", name: "foo")
        XCTAssertEqual(vm.selectedResource, .pods)
        XCTAssertNil(vm.pendingSelection)
    }

    func testSelectNextResource() {
        let vm = ClusterViewModel()
        vm.selectedResource = .pods
        vm.selectNextResource()
        XCTAssertEqual(vm.selectedResource, .deployments)
    }

    func testSelectPreviousResource() {
        let vm = ClusterViewModel()
        vm.selectedResource = .deployments
        vm.selectPreviousResource()
        XCTAssertEqual(vm.selectedResource, .pods)
    }

    func testSelectNextAtEnd() {
        let vm = ClusterViewModel()
        let lastKind = ClusterViewModel.ResourceKind.allCases.last!
        vm.selectedResource = lastKind
        vm.selectNextResource()
        XCTAssertEqual(vm.selectedResource, lastKind)
    }

    func testSelectPreviousAtStart() {
        let vm = ClusterViewModel()
        vm.selectedResource = .pods
        vm.selectPreviousResource()
        XCTAssertEqual(vm.selectedResource, .pods)
    }

    // MARK: - Related Resources Tests

    func testChildPodsOwnedBy() {
        let vm = ClusterViewModel()
        let rs = makeReplicaSet(name: "my-rs", uid: "rs-123")
        vm.pods = [
            makePod(name: "owned-pod", uid: "p1", ownerUID: "rs-123"),
            makePod(name: "other-pod", uid: "p2"),
        ]
        let children = vm.childPods(ownedBy: rs.metadata)
        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children.first?.name, "owned-pod")
    }

    func testChildReplicaSetsOwnedBy() {
        let vm = ClusterViewModel()
        let deploy = makeDeployment(name: "my-deploy", uid: "deploy-1")
        vm.replicaSets = [
            makeReplicaSet(name: "owned-rs", uid: "rs-1", ownerUID: "deploy-1"),
            makeReplicaSet(name: "other-rs", uid: "rs-2"),
        ]
        let children = vm.childReplicaSets(ownedBy: deploy.metadata)
        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children.first?.name, "owned-rs")
    }

    func testPodsOnNode() {
        let vm = ClusterViewModel()
        vm.pods = [
            makePod(name: "pod-on-node", uid: "p1", nodeName: "worker-1"),
            makePod(name: "pod-elsewhere", uid: "p2", nodeName: "worker-2"),
        ]
        let nodePods = vm.podsOnNode(named: "worker-1")
        XCTAssertEqual(nodePods.count, 1)
        XCTAssertEqual(nodePods.first?.name, "pod-on-node")
    }

    func testChildJobsOwnedBy() {
        let vm = ClusterViewModel()
        let cronJob = makeCronJob(name: "my-cj", uid: "cj-1")
        vm.jobs = [
            makeJob(name: "owned-job", uid: "j1", ownerUID: "cj-1"),
            makeJob(name: "other-job", uid: "j2"),
        ]
        let children = vm.childJobs(ownedBy: cronJob.metadata)
        XCTAssertEqual(children.count, 1)
        XCTAssertEqual(children.first?.name, "owned-job")
    }

    // MARK: - Tree Builder Tests

    func testRelatedTreeForDeployment() {
        let vm = ClusterViewModel()
        let deploy = makeDeployment(name: "my-deploy", uid: "deploy-1")
        let rs = makeReplicaSet(name: "my-rs", uid: "rs-1", ownerUID: "deploy-1")
        vm.replicaSets = [rs]
        vm.pods = [
            makePod(name: "pod-1", uid: "pod-1", ownerUID: "rs-1"),
            makePod(name: "pod-2", uid: "pod-2", ownerUID: "rs-1"),
            makePod(name: "other-pod", uid: "pod-3"),
        ]
        let tree = vm.relatedTreeForDeployment(deploy)
        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree[0].kind, "ReplicaSet")
        XCTAssertEqual(tree[0].name, "my-rs")
        XCTAssertEqual(tree[0].children.count, 2)
    }

    func testRelatedTreeForJob() {
        let vm = ClusterViewModel()
        let job = makeJob(name: "my-job", uid: "job-1")
        vm.pods = [
            makePod(name: "job-pod", uid: "jp1", ownerUID: "job-1"),
            makePod(name: "other", uid: "op1"),
        ]
        let tree = vm.relatedTreeForJob(job)
        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree[0].kind, "Pod")
        XCTAssertEqual(tree[0].name, "job-pod")
    }

    func testRelatedTreeForNode() {
        let vm = ClusterViewModel()
        let node = makeNode(name: "worker-1", uid: "n1")
        vm.pods = [
            makePod(name: "pod-on-node", uid: "p1", nodeName: "worker-1"),
            makePod(name: "pod-elsewhere", uid: "p2", nodeName: "worker-2"),
        ]
        let tree = vm.relatedTreeForNode(node)
        XCTAssertEqual(tree.count, 1)
        XCTAssertEqual(tree[0].name, "pod-on-node")
    }

    // MARK: - Auto-Refresh Interval Tests

    func testAutoRefreshDefaultIsTwoSeconds() {
        let vm = ClusterViewModel()
        XCTAssertEqual(vm.autoRefreshInterval, .twoSeconds)
        XCTAssertEqual(vm.autoRefreshInterval.rawValue, 2)
    }

    func testAutoRefreshIntervalLabels() {
        XCTAssertEqual(ClusterViewModel.AutoRefreshInterval.off.label, "Off")
        XCTAssertEqual(ClusterViewModel.AutoRefreshInterval.twoSeconds.label, "2s")
        XCTAssertEqual(ClusterViewModel.AutoRefreshInterval.fifteenSeconds.label, "15s")
        XCTAssertEqual(ClusterViewModel.AutoRefreshInterval.thirtySeconds.label, "30s")
        XCTAssertEqual(ClusterViewModel.AutoRefreshInterval.sixtySeconds.label, "60s")
    }

    func testAutoRefreshIntervalAllCases() {
        let allCases = ClusterViewModel.AutoRefreshInterval.allCases
        XCTAssertEqual(allCases.count, 5)
        XCTAssertEqual(allCases.map(\.rawValue), [0, 2, 15, 30, 60])
    }

    func testSetAutoRefreshInterval() {
        let vm = ClusterViewModel()
        vm.setAutoRefreshInterval(.thirtySeconds)
        XCTAssertEqual(vm.autoRefreshInterval, .thirtySeconds)
    }

    // MARK: - Metrics Lookup Tests

    func testPodMetricsLookup() {
        let vm = ClusterViewModel()
        vm.podMetrics = [
            makePodMetrics(name: "nginx", namespace: "default", cpuMillicores: 100, memoryKi: 512),
            makePodMetrics(name: "redis", namespace: "default", cpuMillicores: 50, memoryKi: 256),
            makePodMetrics(name: "nginx", namespace: "other", cpuMillicores: 200, memoryKi: 1024),
        ]
        let pod = makePod(name: "nginx", namespace: "default", uid: "p1")
        let m = vm.metrics(for: pod)
        XCTAssertNotNil(m)
        XCTAssertEqual(m?.totalCPUMillicores, 100)
    }

    func testPodMetricsLookupNamespaceSeparation() {
        let vm = ClusterViewModel()
        vm.podMetrics = [
            makePodMetrics(name: "nginx", namespace: "other", cpuMillicores: 999, memoryKi: 999),
        ]
        let pod = makePod(name: "nginx", namespace: "default", uid: "p1")
        XCTAssertNil(vm.metrics(for: pod))
    }

    func testNodeMetricsLookup() {
        let vm = ClusterViewModel()
        vm.nodeMetrics = [
            makeNodeMetrics(name: "worker-1", cpuMillicores: 800, memoryKi: 4096),
            makeNodeMetrics(name: "worker-2", cpuMillicores: 400, memoryKi: 2048),
        ]
        let node = makeNode(name: "worker-1", uid: "n1")
        let m = vm.metrics(for: node)
        XCTAssertNotNil(m)
        XCTAssertEqual(m?.cpuMillicores, 800)
    }

    func testNodeMetricsLookupMissing() {
        let vm = ClusterViewModel()
        vm.nodeMetrics = []
        let node = makeNode(name: "worker-1", uid: "n1")
        XCTAssertNil(vm.metrics(for: node))
    }

    // MARK: - Misc Tests

    func testIsAllNamespaces() {
        let vm = ClusterViewModel()
        vm.selectedNamespace = ""
        XCTAssertTrue(vm.isAllNamespaces)
        vm.selectedNamespace = "default"
        XCTAssertFalse(vm.isAllNamespaces)
    }

    func testResourceKindRoundTrip() {
        for kind in ClusterViewModel.ResourceKind.allCases {
            let k8sKind = kind.kubernetesKind
            guard !k8sKind.isEmpty else { continue } // skip non-K8s entries (e.g. portForwards)
            let roundTripped = ClusterViewModel.ResourceKind.from(kubernetesKind: k8sKind)
            XCTAssertEqual(roundTripped, kind, "Round-trip failed for \(kind)")
        }
    }
}
