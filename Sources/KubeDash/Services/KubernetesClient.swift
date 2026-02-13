import Foundation

// MARK: - Kubernetes Client

final class KubernetesClient: NSObject, @unchecked Sendable {
    let baseURL: URL
    let authProvider: AuthProvider
    private let clusterConfig: KubeConfig.Cluster
    private let decoder: JSONDecoder

    // Lazy so `self` is available as delegate
    private lazy var _session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 300
        return URLSession(
            configuration: config,
            delegate: self,
            delegateQueue: nil
        )
    }()

    init(cluster: KubeConfig.Cluster, authProvider: AuthProvider) throws {
        guard let url = URL(string: cluster.server) else {
            throw KubernetesError.connectionFailed(
                underlying: URLError(.badURL)
            )
        }
        self.baseURL = url
        self.authProvider = authProvider
        self.clusterConfig = cluster
        self.decoder = JSONDecoder()
        super.init()
    }

    // MARK: - List Resources

    func list<T: KubernetesResource>(
        _ type: T.Type,
        namespace: String? = nil,
        labelSelector: String? = nil
    ) async throws -> [T] {
        let url = buildURL(for: type, namespace: namespace, labelSelector: labelSelector)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try await authProvider.authenticate(&request)

        let (data, response) = try await _session.data(for: request)
        try validateResponse(response, data: data)

        let list = try decoder.decode(KubernetesList<T>.self, from: data)
        return list.items
    }

    // MARK: - Get Single Resource

    func get<T: KubernetesResource>(
        _ type: T.Type,
        name: String,
        namespace: String? = nil
    ) async throws -> T {
        let url = buildURL(for: type, namespace: namespace)
            .appendingPathComponent(name)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try await authProvider.authenticate(&request)

        let (data, response) = try await _session.data(for: request)
        try validateResponse(response, data: data)

        return try decoder.decode(T.self, from: data)
    }

    // MARK: - Watch Resources

    func watch<T: KubernetesResource>(
        _ type: T.Type,
        namespace: String? = nil,
        resourceVersion: String? = nil
    ) -> AsyncThrowingStream<WatchEvent<T>, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var urlComponents = URLComponents(
                        url: buildURL(for: type, namespace: namespace),
                        resolvingAgainstBaseURL: false
                    )!
                    var queryItems = [URLQueryItem(name: "watch", value: "true")]
                    if let rv = resourceVersion {
                        queryItems.append(URLQueryItem(name: "resourceVersion", value: rv))
                    }
                    urlComponents.queryItems = queryItems

                    var request = URLRequest(url: urlComponents.url!)
                    request.httpMethod = "GET"
                    request.setValue("application/json", forHTTPHeaderField: "Accept")
                    request.timeoutInterval = 0 // No timeout for watch
                    try await authProvider.authenticate(&request)

                    let (bytes, response) = try await _session.bytes(for: request)
                    try validateResponse(response, data: nil)

                    var buffer = Data()
                    for try await byte in bytes {
                        buffer.append(byte)

                        // K8s sends one JSON object per line
                        if byte == UInt8(ascii: "\n") {
                            if !buffer.isEmpty {
                                let event = try decoder.decode(
                                    WatchEvent<T>.self, from: buffer
                                )
                                continuation.yield(event)
                                buffer.removeAll(keepingCapacity: true)
                            }
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Pod Logs

    func logs(
        podName: String,
        namespace: String,
        container: String? = nil,
        follow: Bool = false,
        tailLines: Int? = nil
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    var url = baseURL
                        .appendingPathComponent("api/v1")
                        .appendingPathComponent("namespaces/\(namespace)")
                        .appendingPathComponent("pods/\(podName)/log")

                    var queryItems: [URLQueryItem] = []
                    if let container = container {
                        queryItems.append(URLQueryItem(name: "container", value: container))
                    }
                    if follow {
                        queryItems.append(URLQueryItem(name: "follow", value: "true"))
                    }
                    if let tail = tailLines {
                        queryItems.append(URLQueryItem(name: "tailLines", value: String(tail)))
                    }

                    if !queryItems.isEmpty {
                        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
                        components.queryItems = queryItems
                        url = components.url!
                    }

                    var request = URLRequest(url: url)
                    request.httpMethod = "GET"
                    request.timeoutInterval = follow ? 0 : 30
                    try await authProvider.authenticate(&request)

                    let (bytes, response) = try await _session.bytes(for: request)
                    try validateResponse(response, data: nil)

                    var lineBuffer = ""
                    for try await byte in bytes {
                        let char = Character(UnicodeScalar(byte))
                        if char == "\n" {
                            continuation.yield(lineBuffer)
                            lineBuffer = ""
                        } else {
                            lineBuffer.append(char)
                        }
                    }
                    if !lineBuffer.isEmpty {
                        continuation.yield(lineBuffer)
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - Get Namespaces

    func namespaces() async throws -> [String] {
        let url = baseURL.appendingPathComponent("api/v1/namespaces")
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try await authProvider.authenticate(&request)

        let (data, response) = try await _session.data(for: request)
        try validateResponse(response, data: data)

        struct NamespaceList: Decodable {
            let items: [NamespaceItem]
        }
        struct NamespaceItem: Decodable {
            let metadata: ObjectMetadata
        }

        let list = try decoder.decode(NamespaceList.self, from: data)
        return list.items.map(\.metadata.name).sorted()
    }

    // MARK: - Raw YAML/JSON for a Resource

    func rawJSON(path: String) async throws -> Data {
        let url = baseURL.appendingPathComponent(path)
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        try await authProvider.authenticate(&request)

        let (data, response) = try await _session.data(for: request)
        try validateResponse(response, data: data)
        return data
    }

    // MARK: - Helpers

    private func buildURL<T: KubernetesResource>(
        for type: T.Type,
        namespace: String?,
        labelSelector: String? = nil
    ) -> URL {
        var path = T.apiPath
        if let ns = namespace {
            path += "/namespaces/\(ns)"
        }
        path += "/\(T.kind)"

        var url = baseURL.appendingPathComponent(path)
        if let selector = labelSelector {
            var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
            components.queryItems = [URLQueryItem(name: "labelSelector", value: selector)]
            url = components.url!
        }
        return url
    }

    private func validateResponse(_ response: URLResponse, data: Data?) throws {
        guard let http = response as? HTTPURLResponse else { return }

        guard 200..<300 ~= http.statusCode else {
            var message = "HTTP \(http.statusCode)"
            if let data = data,
               let apiError = try? decoder.decode(KubernetesAPIError.self, from: data)
            {
                message = apiError.message
            }
            throw KubernetesError.apiError(statusCode: http.statusCode, message: message)
        }
    }
}

// MARK: - URLSession Delegate (TLS)

extension KubernetesClient: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let protectionSpace = challenge.protectionSpace

        // Server trust challenge — validate cluster CA
        if protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust {
            guard let serverTrust = protectionSpace.serverTrust else {
                completionHandler(.cancelAuthenticationChallenge, nil)
                return
            }

            // If insecure, accept any certificate
            if clusterConfig.insecureSkipTLSVerify == true {
                completionHandler(
                    .useCredential,
                    URLCredential(trust: serverTrust)
                )
                return
            }

            // If we have a custom CA, set it as trusted
            if let caData = loadCAData() {
                if let caCert = SecCertificateCreateWithData(nil, caData as CFData) {
                    SecTrustSetAnchorCertificates(serverTrust, [caCert] as CFArray)
                    SecTrustSetAnchorCertificatesOnly(serverTrust, false)
                }
            }

            // Evaluate trust
            var error: CFError?
            if SecTrustEvaluateWithError(serverTrust, &error) {
                completionHandler(
                    .useCredential,
                    URLCredential(trust: serverTrust)
                )
            } else {
                completionHandler(.cancelAuthenticationChallenge, nil)
            }
            return
        }

        completionHandler(.performDefaultHandling, nil)
    }

    private func loadCAData() -> Data? {
        if let b64 = clusterConfig.certificateAuthorityData {
            return Data(base64Encoded: b64)
        }
        if let path = clusterConfig.certificateAuthority {
            let expanded = (path as NSString).expandingTildeInPath
            return try? Data(contentsOf: URL(fileURLWithPath: expanded))
        }
        return nil
    }
}
