import XCTest
@testable import Kamera

final class KubeConfigTests: XCTestCase {

    let sampleKubeconfig = """
    apiVersion: v1
    kind: Config
    current-context: dev-cluster
    clusters:
    - name: dev-cluster
      cluster:
        server: https://dev.example.com:6443
        certificate-authority-data: dGVzdC1jYS1kYXRh
    - name: prod-cluster
      cluster:
        server: https://prod.example.com:6443
        insecure-skip-tls-verify: true
    contexts:
    - name: dev-cluster
      context:
        cluster: dev-cluster
        user: dev-user
        namespace: development
    - name: prod-cluster
      context:
        cluster: prod-cluster
        user: prod-user
    users:
    - name: dev-user
      user:
        token: dev-token-12345
    - name: prod-user
      user:
        exec:
          apiVersion: client.authentication.k8s.io/v1beta1
          command: aws
          args:
          - eks
          - get-token
          - --cluster-name
          - prod
    """

    func testParseConfig() throws {
        let url = writeTempFile(content: sampleKubeconfig)
        let config = try KubeConfig.load(from: url)

        XCTAssertEqual(config.currentContext, "dev-cluster")
        XCTAssertEqual(config.clusters.count, 2)
        XCTAssertEqual(config.contexts.count, 2)
        XCTAssertEqual(config.users.count, 2)
    }

    func testCurrentContext() throws {
        let url = writeTempFile(content: sampleKubeconfig)
        let config = try KubeConfig.load(from: url)

        let current = config.currentContextEntry()
        XCTAssertEqual(current?.name, "dev-cluster")
        XCTAssertEqual(current?.context.namespace, "development")
    }

    func testClusterLookup() throws {
        let url = writeTempFile(content: sampleKubeconfig)
        let config = try KubeConfig.load(from: url)

        let cluster = config.cluster(forContext: "dev-cluster")
        XCTAssertEqual(cluster?.server, "https://dev.example.com:6443")
        XCTAssertEqual(cluster?.certificateAuthorityData, "dGVzdC1jYS1kYXRh")

        let prodCluster = config.cluster(forContext: "prod-cluster")
        XCTAssertEqual(prodCluster?.insecureSkipTLSVerify, true)
    }

    func testUserLookup() throws {
        let url = writeTempFile(content: sampleKubeconfig)
        let config = try KubeConfig.load(from: url)

        let devUser = config.user(forContext: "dev-cluster")
        XCTAssertEqual(devUser?.token, "dev-token-12345")

        let prodUser = config.user(forContext: "prod-cluster")
        XCTAssertEqual(prodUser?.exec?.command, "aws")
        XCTAssertEqual(prodUser?.exec?.args, ["eks", "get-token", "--cluster-name", "prod"])
    }

    func testNamespaceFallback() throws {
        let url = writeTempFile(content: sampleKubeconfig)
        let config = try KubeConfig.load(from: url)

        XCTAssertEqual(config.namespace(forContext: "dev-cluster"), "development")
        XCTAssertEqual(config.namespace(forContext: "prod-cluster"), "default")
    }

    func testNonexistentContext() throws {
        let url = writeTempFile(content: sampleKubeconfig)
        let config = try KubeConfig.load(from: url)

        XCTAssertNil(config.cluster(forContext: "nonexistent"))
        XCTAssertNil(config.user(forContext: "nonexistent"))
    }

    // MARK: - Helpers

    private func writeTempFile(content: String) -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let url = tmpDir.appendingPathComponent("test-kubeconfig-\(UUID().uuidString)")
        try! content.write(to: url, atomically: true, encoding: .utf8)
        addTeardownBlock { try? FileManager.default.removeItem(at: url) }
        return url
    }
}
