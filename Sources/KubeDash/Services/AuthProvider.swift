import Foundation

// MARK: - AuthProvider

actor AuthProvider {
    private let userInfo: KubeConfig.UserInfo
    private var cachedExecToken: String?
    private var tokenExpiry: Date?

    init(userInfo: KubeConfig.UserInfo) {
        self.userInfo = userInfo
    }

    /// Apply authentication to a URLRequest
    func authenticate(_ request: inout URLRequest) async throws {
        if let token = try await resolveToken() {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
    }

    /// Get a bearer token from the available auth methods
    private func resolveToken() async throws -> String? {
        // Direct token
        if let token = userInfo.token {
            return token
        }

        // Exec-based auth (EKS, GKE, etc.)
        if let exec = userInfo.exec {
            return try await execToken(config: exec)
        }

        // Client cert auth is handled at the URLSession delegate level
        return nil
    }

    // MARK: - Exec-based Auth

    private func execToken(config: KubeConfig.ExecConfig) async throws -> String {
        // Return cached token if still valid
        if let cached = cachedExecToken, let expiry = tokenExpiry, Date() < expiry {
            return cached
        }

        let token = try await runExecPlugin(config: config)
        return token
    }

    private func runExecPlugin(config: KubeConfig.ExecConfig) async throws -> String {
        let process = Process()

        // Resolve the command path
        let command = config.command
        if command.hasPrefix("/") {
            process.executableURL = URL(fileURLWithPath: command)
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            var args = [command]
            if let execArgs = config.args {
                args.append(contentsOf: execArgs)
            }
            process.arguments = args
        }

        if process.executableURL?.lastPathComponent != "env", let args = config.args {
            process.arguments = args
        }

        // Set environment variables
        if let envVars = config.env {
            var environment = ProcessInfo.processInfo.environment
            for envVar in envVars {
                environment[envVar.name] = envVar.value
            }
            process.environment = environment
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8) ?? "unknown error"
            throw KubernetesError.authenticationFailed(
                "exec plugin '\(command)' failed: \(errorMessage)"
            )
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        let credential = try JSONDecoder().decode(ExecCredential.self, from: data)

        // Cache the token
        cachedExecToken = credential.status.token
        if let expiry = credential.status.expirationTimestamp {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            tokenExpiry = formatter.date(from: expiry)
        }

        return credential.status.token
    }

    // MARK: - Client Certificate

    /// Whether this auth config uses client certificate authentication
    var usesClientCertificate: Bool {
        (userInfo.clientCertificateData != nil || userInfo.clientCertificate != nil)
            && (userInfo.clientKeyData != nil || userInfo.clientKey != nil)
    }

    /// Load client certificate data for TLS
    func clientCertificateData() throws -> (certData: Data, keyData: Data)? {
        let certData: Data?
        let keyData: Data?

        if let b64Cert = userInfo.clientCertificateData {
            certData = Data(base64Encoded: b64Cert)
        } else if let certPath = userInfo.clientCertificate {
            let expanded = (certPath as NSString).expandingTildeInPath
            certData = try Data(contentsOf: URL(fileURLWithPath: expanded))
        } else {
            certData = nil
        }

        if let b64Key = userInfo.clientKeyData {
            keyData = Data(base64Encoded: b64Key)
        } else if let keyPath = userInfo.clientKey {
            let expanded = (keyPath as NSString).expandingTildeInPath
            keyData = try Data(contentsOf: URL(fileURLWithPath: expanded))
        } else {
            keyData = nil
        }

        guard let cert = certData, let key = keyData else { return nil }
        return (cert, key)
    }
}

// MARK: - Exec Credential Response

struct ExecCredential: Decodable {
    let apiVersion: String
    let kind: String
    let status: ExecCredentialStatus
}

struct ExecCredentialStatus: Decodable {
    let token: String
    let expirationTimestamp: String?
}
