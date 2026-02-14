import Foundation

// MARK: - Watch Event

struct WatchEvent<T: KubernetesResource>: Decodable {
    let type: EventType
    let object: T

    enum EventType: String, Decodable {
        case added = "ADDED"
        case modified = "MODIFIED"
        case deleted = "DELETED"
        case error = "ERROR"
    }
}

// MARK: - K8s API Error

struct KubernetesAPIError: Decodable {
    let kind: String
    let apiVersion: String
    let metadata: EmptyMetadata?
    let status: String
    let message: String
    let reason: String?
    let code: Int

    struct EmptyMetadata: Decodable {}
}

// MARK: - Client Errors

enum KubernetesError: LocalizedError {
    case apiError(statusCode: Int, message: String)
    case connectionFailed(underlying: Error)
    case decodingFailed(underlying: Error)
    case authenticationFailed(String)
    case notConnected

    var errorDescription: String? {
        switch self {
        case .apiError(let code, let message):
            return "K8s API error (\(code)): \(message)"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        case .decodingFailed(let error):
            return "Failed to decode response: \(error.localizedDescription)"
        case .authenticationFailed(let message):
            return "Authentication failed: \(message)"
        case .notConnected:
            return "Not connected to a cluster"
        }
    }
}
