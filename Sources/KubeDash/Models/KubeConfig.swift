import Foundation
import Yams

// MARK: - KubeConfig Model

struct KubeConfig: Codable {
    var apiVersion: String?
    var kind: String?
    var currentContext: String?
    var clusters: [NamedCluster]
    var contexts: [NamedContext]
    var users: [NamedUser]

    enum CodingKeys: String, CodingKey {
        case apiVersion
        case kind
        case currentContext = "current-context"
        case clusters
        case contexts
        case users
    }
}

// MARK: - Cluster

extension KubeConfig {
    struct NamedCluster: Codable {
        var name: String
        var cluster: Cluster
    }

    struct Cluster: Codable {
        var server: String
        var certificateAuthority: String?
        var certificateAuthorityData: String?
        var insecureSkipTLSVerify: Bool?

        enum CodingKeys: String, CodingKey {
            case server
            case certificateAuthority = "certificate-authority"
            case certificateAuthorityData = "certificate-authority-data"
            case insecureSkipTLSVerify = "insecure-skip-tls-verify"
        }
    }
}

// MARK: - Context

extension KubeConfig {
    struct NamedContext: Codable, Identifiable {
        var id: String { name }
        var name: String
        var context: Context
    }

    struct Context: Codable {
        var cluster: String
        var user: String
        var namespace: String?
    }
}

// MARK: - User

extension KubeConfig {
    struct NamedUser: Codable {
        var name: String
        var user: UserInfo
    }

    struct UserInfo: Codable {
        var token: String?
        var clientCertificate: String?
        var clientCertificateData: String?
        var clientKey: String?
        var clientKeyData: String?
        var exec: ExecConfig?

        enum CodingKeys: String, CodingKey {
            case token
            case clientCertificate = "client-certificate"
            case clientCertificateData = "client-certificate-data"
            case clientKey = "client-key"
            case clientKeyData = "client-key-data"
            case exec
        }
    }

    struct ExecConfig: Codable {
        var apiVersion: String?
        var command: String
        var args: [String]?
        var env: [ExecEnvVar]?
    }

    struct ExecEnvVar: Codable {
        var name: String
        var value: String
    }
}

// MARK: - Loading & Convenience

extension KubeConfig {
    static var defaultConfigURL: URL {
        if let envPath = ProcessInfo.processInfo.environment["KUBECONFIG"] {
            return URL(fileURLWithPath: envPath)
        }
        return FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".kube/config")
    }

    static func load(from url: URL = defaultConfigURL) throws -> KubeConfig {
        let data = try Data(contentsOf: url)
        guard let yaml = String(data: data, encoding: .utf8) else {
            throw KubeConfigError.invalidEncoding
        }
        let decoder = YAMLDecoder()
        return try decoder.decode(KubeConfig.self, from: yaml)
    }

    func currentContextEntry() -> NamedContext? {
        guard let name = currentContext else { return nil }
        return contexts.first { $0.name == name }
    }

    func cluster(forContext contextName: String) -> Cluster? {
        guard let ctx = contexts.first(where: { $0.name == contextName }) else { return nil }
        return clusters.first { $0.name == ctx.context.cluster }?.cluster
    }

    func user(forContext contextName: String) -> UserInfo? {
        guard let ctx = contexts.first(where: { $0.name == contextName }) else { return nil }
        return users.first { $0.name == ctx.context.user }?.user
    }

    func namespace(forContext contextName: String) -> String {
        contexts.first { $0.name == contextName }?.context.namespace ?? "default"
    }
}

// MARK: - Errors

enum KubeConfigError: LocalizedError {
    case invalidEncoding
    case contextNotFound(String)
    case clusterNotFound(String)
    case userNotFound(String)

    var errorDescription: String? {
        switch self {
        case .invalidEncoding:
            return "Kubeconfig file is not valid UTF-8"
        case .contextNotFound(let name):
            return "Context '\(name)' not found in kubeconfig"
        case .clusterNotFound(let name):
            return "Cluster '\(name)' not found in kubeconfig"
        case .userNotFound(let name):
            return "User '\(name)' not found in kubeconfig"
        }
    }
}
