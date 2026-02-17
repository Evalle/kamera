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

        // auth-provider based auth (GKE gcp, OIDC, etc.)
        if let provider = userInfo.authProvider {
            return try await authProviderToken(provider: provider)
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
        let command = config.command
        let args = config.args ?? []

        // Build the full command string for shell execution
        // This ensures the user's PATH is used (aws, gcloud, kubelogin, etc.)
        let fullCommand: String
        if command.hasPrefix("/") {
            // Absolute path — use directly
            let escapedArgs = args.map { shellEscape($0) }.joined(separator: " ")
            fullCommand = "\(shellEscape(command)) \(escapedArgs)"
        } else {
            // Relative command — let the shell resolve it via PATH
            let escapedArgs = args.map { shellEscape($0) }.joined(separator: " ")
            fullCommand = "\(shellEscape(command)) \(escapedArgs)"
        }

        let process = Process()
        // Use login shell to get the user's full PATH
        // (macOS apps have a minimal PATH that won't include Homebrew, etc.)
        process.executableURL = Shell.loginShellURL
        process.arguments = ["-l", "-c", fullCommand]

        // Set environment variables from exec config
        var environment = ProcessInfo.processInfo.environment
        if let envVars = config.env {
            for envVar in envVars {
                environment[envVar.name] = envVar.value
            }
        }
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw KubernetesError.authenticationFailed(
                "Failed to run exec plugin '\(command)': \(error.localizedDescription)"
            )
        }

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? "unknown error"
            throw KubernetesError.authenticationFailed(
                "exec plugin '\(command)' exited with code \(process.terminationStatus): \(errorMessage)"
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
                ?? ISO8601DateFormatter().date(from: expiry) // fallback without fractional seconds
        }

        return credential.status.token
    }

    // MARK: - Auth-Provider Based Auth

    private func authProviderToken(provider: KubeConfig.AuthProviderConfig) async throws -> String {
        let config = provider.config ?? [:]

        switch provider.name {
        case "gcp":
            // Use cached access-token if not expired
            if let token = config["access-token"], let expiryStr = config["expiry"],
               let expiry = ISO8601DateFormatter().date(from: expiryStr), Date() < expiry
            {
                return token
            }
            // Refresh via gcloud
            return try await refreshGCPToken()

        case "oidc":
            if let token = config["id-token"] {
                return token
            }
            throw KubernetesError.authenticationFailed(
                "OIDC auth-provider has no id-token in config"
            )

        default:
            // Generic fallback: try common token fields
            if let token = config["access-token"] ?? config["token"] {
                return token
            }
            throw KubernetesError.authenticationFailed(
                "auth-provider '\(provider.name)' has no usable token in config"
            )
        }
    }

    private func refreshGCPToken() async throws -> String {
        let process = Process()
        process.executableURL = Shell.loginShellURL
        process.arguments = ["-l", "-c", "gcloud config config-helper --format=json"]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            throw KubernetesError.authenticationFailed(
                "Failed to run gcloud: \(error.localizedDescription)"
            )
        }

        guard process.terminationStatus == 0 else {
            let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
            let errorMessage = String(data: errorData, encoding: .utf8)?.trimmingCharacters(
                in: .whitespacesAndNewlines
            ) ?? "unknown error"
            throw KubernetesError.authenticationFailed(
                "gcloud exited with code \(process.terminationStatus): \(errorMessage)"
            )
        }

        let data = stdout.fileHandleForReading.readDataToEndOfFile()
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let credential = json["credential"] as? [String: Any],
              let token = credential["access_token"] as? String
        else {
            throw KubernetesError.authenticationFailed(
                "Failed to parse access_token from gcloud config-helper output"
            )
        }

        // Cache the refreshed token
        cachedExecToken = token
        if let expiryStr = credential["token_expiry"] as? String {
            tokenExpiry = ISO8601DateFormatter().date(from: expiryStr)
        }

        return token
    }

    /// Shell-escape a string for safe use in sh -c
    private func shellEscape(_ s: String) -> String {
        if s.isEmpty { return "''" }
        // If the string only contains safe characters, return as-is
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "/-_.=:@"))
        if s.unicodeScalars.allSatisfy({ safe.contains($0) }) {
            return s
        }
        // Otherwise, wrap in single quotes and escape any embedded single quotes
        return "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
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
