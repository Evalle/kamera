import XCTest
@testable import Kamera

@MainActor
final class PortForwardManagerTests: XCTestCase {

    // MARK: - Forward Model

    func testDisplayTitleForPod() {
        let forward = makeForward(resourceType: .pod, resourceName: "my-pod")
        XCTAssertEqual(forward.displayTitle, "Pod/my-pod")
    }

    func testDisplayTitleForService() {
        let forward = makeForward(resourceType: .service, resourceName: "my-svc")
        XCTAssertEqual(forward.displayTitle, "Service/my-svc")
    }

    func testPortMapping() {
        let forward = makeForward(localPort: 8080, remotePort: 80)
        XCTAssertEqual(forward.portMapping, "8080 → 80")
    }

    func testLocalURL() {
        let forward = makeForward(localPort: 3000)
        XCTAssertEqual(forward.localURL, URL(string: "http://localhost:3000"))
    }

    func testResourceTypeRawValue() {
        XCTAssertEqual(PortForwardManager.Forward.ResourceType.pod.rawValue, "pod")
        XCTAssertEqual(PortForwardManager.Forward.ResourceType.service.rawValue, "svc")
    }

    func testResourceTypeDisplayName() {
        XCTAssertEqual(PortForwardManager.Forward.ResourceType.pod.displayName, "Pod")
        XCTAssertEqual(PortForwardManager.Forward.ResourceType.service.displayName, "Service")
    }

    func testStatusEquality() {
        XCTAssertEqual(PortForwardManager.Forward.Status.starting, .starting)
        XCTAssertEqual(PortForwardManager.Forward.Status.active, .active)
        XCTAssertEqual(PortForwardManager.Forward.Status.failed("err"), .failed("err"))
        XCTAssertNotEqual(PortForwardManager.Forward.Status.active, .starting)
        XCTAssertNotEqual(PortForwardManager.Forward.Status.failed("a"), .failed("b"))
    }

    // MARK: - activeCount

    func testActiveCountEmpty() {
        let manager = PortForwardManager()
        XCTAssertEqual(manager.activeCount, 0)
    }

    func testActiveCountOnlyCountsActive() {
        let manager = PortForwardManager()
        manager.forwards = [
            makeForward(status: .starting),
            makeForward(status: .active),
            makeForward(status: .active),
            makeForward(status: .failed("err")),
        ]
        XCTAssertEqual(manager.activeCount, 2)
    }

    func testActiveCountAllStarting() {
        let manager = PortForwardManager()
        manager.forwards = [makeForward(status: .starting), makeForward(status: .starting)]
        XCTAssertEqual(manager.activeCount, 0)
    }

    // MARK: - stopForward

    func testStopForwardRemovesEntry() {
        let manager = PortForwardManager()
        let fwd = makeForward()
        manager.forwards = [fwd]
        manager.stopForward(id: fwd.id)
        XCTAssertTrue(manager.forwards.isEmpty)
    }

    func testStopForwardOnlyRemovesTargeted() {
        let manager = PortForwardManager()
        let fwd1 = makeForward()
        let fwd2 = makeForward()
        manager.forwards = [fwd1, fwd2]
        manager.stopForward(id: fwd1.id)
        XCTAssertEqual(manager.forwards.count, 1)
        XCTAssertEqual(manager.forwards.first?.id, fwd2.id)
    }

    func testStopForwardUnknownIdIsNoop() {
        let manager = PortForwardManager()
        let fwd = makeForward()
        manager.forwards = [fwd]
        manager.stopForward(id: UUID()) // unknown id
        XCTAssertEqual(manager.forwards.count, 1)
    }

    // MARK: - stopAll

    func testStopAllClearsForwards() {
        let manager = PortForwardManager()
        manager.forwards = [makeForward(), makeForward(), makeForward()]
        manager.stopAll()
        XCTAssertTrue(manager.forwards.isEmpty)
    }

    func testStopAllOnEmptyManagerIsNoop() {
        let manager = PortForwardManager()
        manager.stopAll()
        XCTAssertTrue(manager.forwards.isEmpty)
    }

    // MARK: - startForward (state only — does not execute kubectl)

    func testStartForwardAppendsWithStartingStatus() async {
        let manager = PortForwardManager()
        // We can't run real kubectl in tests, but we can verify the entry is appended
        // synchronously before the async process launch.
        // We use a non-existent context so kubectl fails fast; we just check initial state.
        let task = Task {
            await manager.startForward(
                context: "test-context",
                resourceType: .pod,
                resourceName: "test-pod",
                namespace: "default",
                localPort: 9999,
                remotePort: 8080
            )
        }
        // Give the task a moment to append the entry before kubectl path resolution
        try? await Task.sleep(for: .milliseconds(50))
        XCTAssertFalse(manager.forwards.isEmpty, "startForward should append an entry")
        if let entry = manager.forwards.first {
            XCTAssertEqual(entry.resourceName, "test-pod")
            XCTAssertEqual(entry.localPort, 9999)
            XCTAssertEqual(entry.remotePort, 8080)
        }
        task.cancel()
    }

    func testStartForwardSetsCorrectFields() async {
        let manager = PortForwardManager()
        let task = Task {
            await manager.startForward(
                context: "ctx",
                resourceType: .service,
                resourceName: "my-service",
                namespace: "staging",
                localPort: 5432,
                remotePort: 5432
            )
        }
        try? await Task.sleep(for: .milliseconds(50))
        if let entry = manager.forwards.first {
            XCTAssertEqual(entry.context, "ctx")
            XCTAssertEqual(entry.resourceType, .service)
            XCTAssertEqual(entry.namespace, "staging")
        }
        task.cancel()
    }
}

// MARK: - Fixtures

private func makeForward(
    resourceType: PortForwardManager.Forward.ResourceType = .pod,
    resourceName: String = "test-pod",
    namespace: String = "default",
    localPort: Int = 8080,
    remotePort: Int = 80,
    status: PortForwardManager.Forward.Status = .starting
) -> PortForwardManager.Forward {
    PortForwardManager.Forward(
        id: UUID(),
        context: "test-context",
        resourceType: resourceType,
        resourceName: resourceName,
        namespace: namespace,
        localPort: localPort,
        remotePort: remotePort,
        status: status
    )
}
