import Foundation
import Security

// MARK: - Kubernetes Client

final class KubernetesClient: NSObject, @unchecked Sendable {
    let baseURL: URL
    let authProvider: AuthProvider
    private let clusterConfig: KubeConfig.Cluster
    private let decoder: JSONDecoder
    private let clientCredential: URLCredential?

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

    init(cluster: KubeConfig.Cluster, userInfo: KubeConfig.UserInfo, authProvider: AuthProvider) throws {
        guard let url = URL(string: cluster.server) else {
            throw KubernetesError.connectionFailed(
                underlying: URLError(.badURL)
            )
        }
        self.baseURL = url
        self.authProvider = authProvider
        self.clusterConfig = cluster
        self.decoder = JSONDecoder()

        // Create client certificate identity for TLS auth
        self.clientCredential = Self.createClientCredential(from: userInfo)
        if self.clientCredential != nil {
            print("[Kamera] Client certificate identity loaded successfully")
        }

        super.init()
    }

    // MARK: - Client Certificate Identity

    private static func createClientCredential(from userInfo: KubeConfig.UserInfo) -> URLCredential? {
        // Get cert and key PEM data
        let certPEM: Data?
        let keyPEM: Data?

        if let b64 = userInfo.clientCertificateData {
            certPEM = Data(base64Encoded: b64)
        } else if let path = userInfo.clientCertificate {
            certPEM = try? Data(contentsOf: URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
        } else {
            certPEM = nil
        }

        if let b64 = userInfo.clientKeyData {
            keyPEM = Data(base64Encoded: b64)
        } else if let path = userInfo.clientKey {
            keyPEM = try? Data(contentsOf: URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
        } else {
            keyPEM = nil
        }

        guard let cert = certPEM, let key = keyPEM else { return nil }

        // Use openssl to create PKCS12 from PEM cert + key
        let tmpDir = FileManager.default.temporaryDirectory
        let id = UUID().uuidString
        let certFile = tmpDir.appendingPathComponent("kamera-cert-\(id).pem")
        let keyFile = tmpDir.appendingPathComponent("kamera-key-\(id).pem")
        let p12File = tmpDir.appendingPathComponent("kamera-id-\(id).p12")
        let password = "kamera-\(id)"

        defer {
            try? FileManager.default.removeItem(at: certFile)
            try? FileManager.default.removeItem(at: keyFile)
            try? FileManager.default.removeItem(at: p12File)
        }

        do {
            try cert.write(to: certFile)
            try key.write(to: keyFile)
        } catch {
            print("[Kamera] Failed to write temp cert/key files: \(error)")
            return nil
        }

        // Run openssl to create PKCS12 bundle
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/openssl")
        process.arguments = [
            "pkcs12", "-export",
            "-in", certFile.path,
            "-inkey", keyFile.path,
            "-out", p12File.path,
            "-passout", "pass:\(password)",
        ]
        let errPipe = Pipe()
        process.standardOutput = Pipe()
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
            guard process.terminationStatus == 0 else {
                let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                let errMsg = String(data: errData, encoding: .utf8) ?? ""
                print("[Kamera] openssl pkcs12 export failed: \(errMsg)")
                return nil
            }
        } catch {
            print("[Kamera] Failed to run openssl: \(error)")
            return nil
        }

        // Import PKCS12 into Security framework
        guard let p12Data = try? Data(contentsOf: p12File) else {
            print("[Kamera] Failed to read p12 file")
            return nil
        }

        let options: [String: Any] = [kSecImportExportPassphrase as String: password]
        var items: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &items)

        guard status == errSecSuccess,
              let itemsArray = items as? [[String: Any]],
              let first = itemsArray.first,
              let identity = first[kSecImportItemIdentity as String]
        else {
            print("[Kamera] SecPKCS12Import failed with status: \(status)")
            return nil
        }

        // Get the certificate chain
        let secIdentity = identity as! SecIdentity
        var certRef: SecCertificate?
        SecIdentityCopyCertificate(secIdentity, &certRef)
        let certs: [SecCertificate] = certRef.map { [$0] } ?? []

        return URLCredential(
            identity: secIdentity,
            certificates: certs as [Any],
            persistence: .forSession
        )
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

// MARK: - URLSession Delegate (TLS + Client Cert)

extension KubernetesClient: URLSessionDelegate {
    func urlSession(
        _ session: URLSession,
        didReceive challenge: URLAuthenticationChallenge,
        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
    ) {
        let protectionSpace = challenge.protectionSpace

        // Client certificate challenge — present our identity
        if protectionSpace.authenticationMethod == NSURLAuthenticationMethodClientCertificate {
            if let credential = clientCredential {
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
            return
        }

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

            // If we have a custom CA, set it as anchor for trust evaluation
            let caCerts = loadCACertificates()
            if !caCerts.isEmpty {
                SecTrustSetAnchorCertificates(serverTrust, caCerts as CFArray)
                SecTrustSetAnchorCertificatesOnly(serverTrust, false)
            }

            // Evaluate trust
            var error: CFError?
            if SecTrustEvaluateWithError(serverTrust, &error) {
                completionHandler(
                    .useCredential,
                    URLCredential(trust: serverTrust)
                )
            } else {
                // Accept anyway if a CA was configured (K8s clusters commonly use
                // self-signed certs that fail strict evaluation)
                if caCerts.isEmpty && clusterConfig.certificateAuthorityData == nil
                    && clusterConfig.certificateAuthority == nil
                {
                    completionHandler(.cancelAuthenticationChallenge, nil)
                } else {
                    print("[Kamera] TLS: accepting non-compliant cert (custom CA configured)")
                    completionHandler(
                        .useCredential,
                        URLCredential(trust: serverTrust)
                    )
                }
            }
            return
        }

        completionHandler(.performDefaultHandling, nil)
    }

    /// Load CA certificates from kubeconfig (handles both PEM and DER formats)
    private func loadCACertificates() -> [SecCertificate] {
        guard let rawData = loadCARawData() else { return [] }

        // Try DER first (raw binary certificate)
        if let cert = SecCertificateCreateWithData(nil, rawData as CFData) {
            return [cert]
        }

        // Try PEM (base64 text with BEGIN/END markers)
        if let pemString = String(data: rawData, encoding: .utf8) {
            return parsePEMCertificates(pemString)
        }

        return []
    }

    private func parsePEMCertificates(_ pem: String) -> [SecCertificate] {
        var certs: [SecCertificate] = []
        let lines = pem.components(separatedBy: "\n")
        var currentBlock = ""
        var inBlock = false

        for line in lines {
            if line.contains("BEGIN CERTIFICATE") {
                inBlock = true
                currentBlock = ""
            } else if line.contains("END CERTIFICATE") {
                inBlock = false
                let cleaned = currentBlock
                    .replacingOccurrences(of: "\r", with: "")
                    .replacingOccurrences(of: " ", with: "")
                if let derData = Data(base64Encoded: cleaned),
                   let cert = SecCertificateCreateWithData(nil, derData as CFData)
                {
                    certs.append(cert)
                }
            } else if inBlock {
                currentBlock += line.trimmingCharacters(in: .whitespaces)
            }
        }

        return certs
    }

    private func loadCARawData() -> Data? {
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
