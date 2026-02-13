import Foundation

// MARK: - K8s API List Response

struct KubernetesList<T: KubernetesResource>: Decodable {
    let apiVersion: String
    let kind: String
    let metadata: ListMetadata
    let items: [T]
}

struct ListMetadata: Decodable {
    let resourceVersion: String?
    let `continue`: String?
}

// MARK: - Base Protocol

protocol KubernetesResource: Decodable, Identifiable {
    var metadata: ObjectMetadata { get }
    static var apiPath: String { get }
    static var kind: String { get }
}

extension KubernetesResource {
    var id: String { metadata.uid ?? "\(metadata.namespace ?? "")_\(metadata.name)" }
    var name: String { metadata.name }
    var namespace: String? { metadata.namespace }
}

// MARK: - Common Metadata

struct ObjectMetadata: Decodable {
    let name: String
    let namespace: String?
    let uid: String?
    let resourceVersion: String?
    let creationTimestamp: String?
    let labels: [String: String]?
    let annotations: [String: String]?
    let ownerReferences: [OwnerReference]?
}

struct OwnerReference: Decodable {
    let apiVersion: String
    let kind: String
    let name: String
    let uid: String
}

// MARK: - Pod

struct Pod: KubernetesResource {
    static let apiPath = "/api/v1"
    static let kind = "pods"

    let metadata: ObjectMetadata
    let spec: PodSpec?
    let status: PodStatus?
}

struct PodSpec: Decodable {
    let containers: [Container]?
    let nodeName: String?
    let serviceAccountName: String?
    let restartPolicy: String?
}

struct Container: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let image: String?
    let ports: [ContainerPort]?
    let resources: ResourceRequirements?
}

struct ContainerPort: Decodable {
    let containerPort: Int
    let name: String?
    let `protocol`: String?
}

struct ResourceRequirements: Decodable {
    let limits: [String: String]?
    let requests: [String: String]?
}

struct PodStatus: Decodable {
    let phase: String?
    let conditions: [PodCondition]?
    let containerStatuses: [ContainerStatus]?
    let hostIP: String?
    let podIP: String?
    let startTime: String?
}

struct PodCondition: Decodable {
    let type: String
    let status: String
    let reason: String?
    let message: String?
}

struct ContainerStatus: Decodable, Identifiable {
    var id: String { name }
    let name: String
    let ready: Bool
    let restartCount: Int
    let state: ContainerState?
    let image: String?
}

struct ContainerState: Decodable {
    let running: ContainerStateRunning?
    let waiting: ContainerStateWaiting?
    let terminated: ContainerStateTerminated?
}

struct ContainerStateRunning: Decodable {
    let startedAt: String?
}

struct ContainerStateWaiting: Decodable {
    let reason: String?
    let message: String?
}

struct ContainerStateTerminated: Decodable {
    let exitCode: Int
    let reason: String?
    let message: String?
    let finishedAt: String?
}

// MARK: - Deployment

struct Deployment: KubernetesResource {
    static let apiPath = "/apis/apps/v1"
    static let kind = "deployments"

    let metadata: ObjectMetadata
    let spec: DeploymentSpec?
    let status: DeploymentStatus?
}

struct DeploymentSpec: Decodable {
    let replicas: Int?
    let selector: LabelSelector?
}

struct LabelSelector: Decodable {
    let matchLabels: [String: String]?
}

struct DeploymentStatus: Decodable {
    let replicas: Int?
    let readyReplicas: Int?
    let updatedReplicas: Int?
    let availableReplicas: Int?
    let unavailableReplicas: Int?
    let conditions: [DeploymentCondition]?
}

struct DeploymentCondition: Decodable {
    let type: String
    let status: String
    let reason: String?
    let message: String?
}

// MARK: - Service

struct Service: KubernetesResource {
    static let apiPath = "/api/v1"
    static let kind = "services"

    let metadata: ObjectMetadata
    let spec: ServiceSpec?
}

struct ServiceSpec: Decodable {
    let type: String?
    let clusterIP: String?
    let externalIPs: [String]?
    let ports: [ServicePort]?
    let selector: [String: String]?
    let loadBalancerIP: String?
}

struct ServicePort: Decodable, Identifiable {
    var id: String { "\(port)-\(`protocol` ?? "TCP")" }
    let name: String?
    let port: Int
    let targetPort: TargetPort?
    let `protocol`: String?
    let nodePort: Int?
}

enum TargetPort: Decodable {
    case int(Int)
    case string(String)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intValue = try? container.decode(Int.self) {
            self = .int(intValue)
        } else {
            self = .string(try container.decode(String.self))
        }
    }
}

// MARK: - Node

struct Node: KubernetesResource {
    static let apiPath = "/api/v1"
    static let kind = "nodes"

    let metadata: ObjectMetadata
    let status: NodeStatus?
}

struct NodeStatus: Decodable {
    let conditions: [NodeCondition]?
    let addresses: [NodeAddress]?
    let nodeInfo: NodeSystemInfo?
    let capacity: [String: String]?
    let allocatable: [String: String]?
}

struct NodeCondition: Decodable {
    let type: String
    let status: String
    let reason: String?
    let message: String?
}

struct NodeAddress: Decodable {
    let type: String
    let address: String
}

struct NodeSystemInfo: Decodable {
    let machineID: String?
    let systemUUID: String?
    let kernelVersion: String?
    let osImage: String?
    let containerRuntimeVersion: String?
    let kubeletVersion: String?
    let architecture: String?
    let operatingSystem: String?
}

// MARK: - Pod Phase Helpers

extension Pod {
    enum Phase: String {
        case pending = "Pending"
        case running = "Running"
        case succeeded = "Succeeded"
        case failed = "Failed"
        case unknown = "Unknown"
    }

    var phase: Phase {
        Phase(rawValue: status?.phase ?? "Unknown") ?? .unknown
    }

    var isReady: Bool {
        guard let statuses = status?.containerStatuses else { return false }
        return !statuses.isEmpty && statuses.allSatisfy(\.ready)
    }

    var totalRestarts: Int {
        status?.containerStatuses?.reduce(0) { $0 + $1.restartCount } ?? 0
    }

    var readyCount: String {
        let ready = status?.containerStatuses?.filter(\.ready).count ?? 0
        let total = spec?.containers?.count ?? 0
        return "\(ready)/\(total)"
    }

    var statusText: String {
        // Check for waiting containers (CrashLoopBackOff, ImagePullBackOff, etc.)
        if let statuses = status?.containerStatuses {
            for cs in statuses {
                if let waiting = cs.state?.waiting, let reason = waiting.reason {
                    return reason
                }
                if let terminated = cs.state?.terminated, let reason = terminated.reason {
                    return reason
                }
            }
        }
        return status?.phase ?? "Unknown"
    }
}

// MARK: - Deployment Helpers

extension Deployment {
    var readyCount: String {
        let ready = status?.readyReplicas ?? 0
        let total = spec?.replicas ?? 0
        return "\(ready)/\(total)"
    }

    var isAvailable: Bool {
        guard let replicas = spec?.replicas else { return false }
        return (status?.availableReplicas ?? 0) >= replicas
    }
}

// MARK: - Node Helpers

extension Node {
    var isReady: Bool {
        status?.conditions?.first { $0.type == "Ready" }?.status == "True"
    }

    var internalIP: String? {
        status?.addresses?.first { $0.type == "InternalIP" }?.address
    }

    var kubeletVersion: String? {
        status?.nodeInfo?.kubeletVersion
    }

    var osImage: String? {
        status?.nodeInfo?.osImage
    }
}
