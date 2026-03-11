import XCTest
@testable import Kamera

final class ResourceModelTests: XCTestCase {

    // MARK: - Pod Status Badge Tests

    func testPodPhaseRunningReady() {
        let pod = makePod(phase: "Running", containerCount: 1, readyContainers: 1)
        XCTAssertEqual(pod.statusBadge, .healthy)
    }

    func testPodPhaseRunningNotReady() {
        let pod = makePod(phase: "Running", containerCount: 1, readyContainers: 0)
        XCTAssertEqual(pod.statusBadge, .warning)
    }

    func testPodPhasePending() {
        let pod = makePod(phase: "Pending")
        XCTAssertEqual(pod.statusBadge, .pending)
    }

    func testPodPhaseFailed() {
        let pod = makePod(phase: "Failed")
        XCTAssertEqual(pod.statusBadge, .error)
    }

    func testPodPhaseSucceeded() {
        let pod = makePod(phase: "Succeeded")
        XCTAssertEqual(pod.statusBadge, .healthy)
    }

    // MARK: - Pod Property Tests

    func testPodIsReady() {
        let pod = makePod(containerCount: 2, readyContainers: 2)
        XCTAssertTrue(pod.isReady)
    }

    func testPodIsNotReadyNoContainers() {
        let pod = makePod(containerCount: 0)
        XCTAssertFalse(pod.isReady)
    }

    func testPodReadyCount() {
        let pod = makePod(containerCount: 2, readyContainers: 1)
        XCTAssertEqual(pod.readyCount, "1/2")
    }

    func testPodTotalRestarts() {
        let pod = makePod(containerCount: 2, restarts: [3, 5])
        XCTAssertEqual(pod.totalRestarts, 8)
    }

    // MARK: - Pod Resource Helper Tests

    func testPodTotalCPURequestSingleContainer() {
        let pod = makePodWithResources(containerSpecs: [
            ContainerResourceSpec(cpuRequest: "500m")
        ])
        XCTAssertEqual(pod.totalCPURequestMillicores, 500)
    }

    func testPodTotalCPURequestMultipleContainers() {
        let pod = makePodWithResources(containerSpecs: [
            ContainerResourceSpec(cpuRequest: "200m"),
            ContainerResourceSpec(cpuRequest: "300m")
        ])
        XCTAssertEqual(pod.totalCPURequestMillicores, 500)
    }

    func testPodTotalCPURequestPartialContainers() {
        // Only one of two containers has a CPU request — that value is returned
        let pod = makePodWithResources(containerSpecs: [
            ContainerResourceSpec(cpuRequest: "250m"),
            ContainerResourceSpec()
        ])
        XCTAssertEqual(pod.totalCPURequestMillicores, 250)
    }

    func testPodTotalCPURequestNilWhenNoConstraints() {
        let pod = makePodWithResources(containerSpecs: [
            ContainerResourceSpec(),
            ContainerResourceSpec()
        ])
        XCTAssertNil(pod.totalCPURequestMillicores)
    }

    func testPodTotalCPULimitMillicores() {
        let pod = makePodWithResources(containerSpecs: [
            ContainerResourceSpec(cpuLimit: "1"),     // 1 core = 1000m
            ContainerResourceSpec(cpuLimit: "500m")
        ])
        XCTAssertEqual(pod.totalCPULimitMillicores, 1500)
    }

    func testPodTotalMemoryRequestBytes() {
        let pod = makePodWithResources(containerSpecs: [
            ContainerResourceSpec(memRequest: "128Mi"),
            ContainerResourceSpec(memRequest: "256Mi")
        ])
        XCTAssertEqual(pod.totalMemoryRequestBytes, (128 + 256) * 1024 * 1024)
    }

    func testPodTotalMemoryLimitBytes() {
        let pod = makePodWithResources(containerSpecs: [
            ContainerResourceSpec(memLimit: "512Mi")
        ])
        XCTAssertEqual(pod.totalMemoryLimitBytes, 512 * 1024 * 1024)
    }

    func testPodTotalMemoryNilWhenNoConstraints() {
        let pod = makePodWithResources(containerSpecs: [ContainerResourceSpec()])
        XCTAssertNil(pod.totalMemoryRequestBytes)
        XCTAssertNil(pod.totalMemoryLimitBytes)
    }

    func testPodHasResourceConstraintsTrue() {
        let pod = makePodWithResources(containerSpecs: [
            ContainerResourceSpec(cpuRequest: "100m")
        ])
        XCTAssertTrue(pod.hasResourceConstraints)
    }

    func testPodHasResourceConstraintsFalseWhenNone() {
        let pod = makePodWithResources(containerSpecs: [ContainerResourceSpec()])
        XCTAssertFalse(pod.hasResourceConstraints)
    }

    func testPodHasResourceConstraintsTrueForLimitOnly() {
        let pod = makePodWithResources(containerSpecs: [
            ContainerResourceSpec(memLimit: "256Mi")
        ])
        XCTAssertTrue(pod.hasResourceConstraints)
    }

    func testPodNoSpecReturnsNilResources() {
        let json = """
        {
            "metadata": {"name": "bare-pod", "uid": "bare-uid", "creationTimestamp": "2025-01-01T00:00:00Z"},
            "status": {"phase": "Running"}
        }
        """
        let pod: Pod = decode(json)
        XCTAssertNil(pod.totalCPURequestMillicores)
        XCTAssertNil(pod.totalCPULimitMillicores)
        XCTAssertNil(pod.totalMemoryRequestBytes)
        XCTAssertNil(pod.totalMemoryLimitBytes)
        XCTAssertFalse(pod.hasResourceConstraints)
    }

    // MARK: - Deployment Tests

    func testDeploymentIsAvailable() {
        let deploy = makeDeployment(replicas: 3, availableReplicas: 3)
        XCTAssertTrue(deploy.isAvailable)
    }

    func testDeploymentIsUnavailable() {
        let deploy = makeDeployment(replicas: 3, availableReplicas: 1)
        XCTAssertFalse(deploy.isAvailable)
    }

    func testDeploymentNoSpec() {
        let deploy = makeDeployment(replicas: nil)
        XCTAssertFalse(deploy.isAvailable)
    }

    func testDeploymentReadyCount() {
        let deploy = makeDeployment(replicas: 3, readyReplicas: 2)
        XCTAssertEqual(deploy.readyCount, "2/3")
    }

    // MARK: - Job Tests

    func testJobIsComplete() {
        let job = makeJob(isComplete: true)
        XCTAssertTrue(job.isComplete)
    }

    func testJobIsFailed() {
        let job = makeJob(isFailed: true)
        XCTAssertTrue(job.isFailed)
    }

    func testJobNotCompleteOrFailed() {
        let job = makeJob()
        XCTAssertFalse(job.isComplete)
        XCTAssertFalse(job.isFailed)
    }

    func testJobCompletionCount() {
        let job = makeJob(completions: 3, succeeded: 2)
        XCTAssertEqual(job.completionCount, "2/3")
    }

    // MARK: - Quantity Parser Tests

    func testParseMillicores() {
        XCTAssertEqual(parseMillicores("750m"), 750)
        XCTAssertEqual(parseMillicores("1500000000n"), 1500)
        XCTAssertEqual(parseMillicores("2"), 2000)
        XCTAssertNil(parseMillicores(nil))
    }

    func testParseMemoryBytes() {
        XCTAssertEqual(parseMemoryBytes("512Ki"), 524288)
        XCTAssertEqual(parseMemoryBytes("256Mi"), 268435456)
        XCTAssertEqual(parseMemoryBytes("1Gi"),   1073741824)
        XCTAssertNil(parseMemoryBytes(nil))
    }

    func testFormatMillicores() {
        XCTAssertEqual(formatMillicores(750), "750m")
        XCTAssertEqual(formatMillicores(1000), "1")
        XCTAssertEqual(formatMillicores(1500), "1.5")
        XCTAssertEqual(formatMillicores(2000), "2")
    }

    func testFormatBytes() {
        XCTAssertEqual(formatBytes(524288), "512Ki")
        XCTAssertEqual(formatBytes(1073741824), "1Gi")
        XCTAssertEqual(formatBytes(512), "512B")
    }

    // MARK: - Node Tests

    func testNodeIsReady() {
        let node = makeNode(isReady: true)
        XCTAssertTrue(node.isReady)
    }

    func testNodeNotReady() {
        let node = makeNode(isReady: false)
        XCTAssertFalse(node.isReady)
    }

    func testNodeNoConditions() {
        let json = """
        {
            "metadata": {"name": "bare-node", "uid": "node-bare", "creationTimestamp": "2025-01-01T00:00:00Z"},
            "status": {}
        }
        """
        let node: Node = decode(json)
        XCTAssertFalse(node.isReady)
    }

    // MARK: - Event Tests

    func testEventIsWarning() {
        let event = makeEvent(type: "Warning")
        XCTAssertTrue(event.isWarning)
    }

    func testEventIsNotWarning() {
        let event = makeEvent(type: "Normal")
        XCTAssertFalse(event.isWarning)
    }
}
