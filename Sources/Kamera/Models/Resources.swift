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

// MARK: - StatefulSet

struct StatefulSet: KubernetesResource {
    static let apiPath = "/apis/apps/v1"
    static let kind = "statefulsets"

    let metadata: ObjectMetadata
    let spec: StatefulSetSpec?
    let status: StatefulSetStatus?
}

struct StatefulSetSpec: Decodable {
    let replicas: Int?
    let serviceName: String?
    let selector: LabelSelector?
}

struct StatefulSetStatus: Decodable {
    let replicas: Int?
    let readyReplicas: Int?
    let currentReplicas: Int?
    let updatedReplicas: Int?
}

// MARK: - DaemonSet

struct DaemonSet: KubernetesResource {
    static let apiPath = "/apis/apps/v1"
    static let kind = "daemonsets"

    let metadata: ObjectMetadata
    let spec: DaemonSetSpec?
    let status: DaemonSetStatus?
}

struct DaemonSetSpec: Decodable {
    let selector: LabelSelector?
}

struct DaemonSetStatus: Decodable {
    let desiredNumberScheduled: Int?
    let currentNumberScheduled: Int?
    let numberReady: Int?
    let numberAvailable: Int?
    let numberMisscheduled: Int?
    let updatedNumberScheduled: Int?
}

// MARK: - ReplicaSet

struct ReplicaSet: KubernetesResource {
    static let apiPath = "/apis/apps/v1"
    static let kind = "replicasets"

    let metadata: ObjectMetadata
    let spec: ReplicaSetSpec?
    let status: ReplicaSetStatus?
}

struct ReplicaSetSpec: Decodable {
    let replicas: Int?
    let selector: LabelSelector?
}

struct ReplicaSetStatus: Decodable {
    let replicas: Int?
    let readyReplicas: Int?
    let availableReplicas: Int?
}

// MARK: - Job

struct Job: KubernetesResource {
    static let apiPath = "/apis/batch/v1"
    static let kind = "jobs"

    let metadata: ObjectMetadata
    let spec: JobSpec?
    let status: JobStatus?
}

struct JobSpec: Decodable {
    let completions: Int?
    let parallelism: Int?
    let backoffLimit: Int?
    let activeDeadlineSeconds: Int?
}

struct JobStatus: Decodable {
    let active: Int?
    let succeeded: Int?
    let failed: Int?
    let startTime: String?
    let completionTime: String?
    let conditions: [JobCondition]?
}

struct JobCondition: Decodable {
    let type: String
    let status: String
    let reason: String?
    let message: String?
}

// MARK: - CronJob

struct CronJob: KubernetesResource {
    static let apiPath = "/apis/batch/v1"
    static let kind = "cronjobs"

    let metadata: ObjectMetadata
    let spec: CronJobSpec?
    let status: CronJobStatus?
}

struct CronJobSpec: Decodable {
    let schedule: String?
    let suspend: Bool?
    let concurrencyPolicy: String?
    let successfulJobsHistoryLimit: Int?
    let failedJobsHistoryLimit: Int?
}

struct CronJobStatus: Decodable {
    let active: [CronJobActiveRef]?
    let lastScheduleTime: String?
    let lastSuccessfulTime: String?
}

struct CronJobActiveRef: Decodable {
    let name: String?
    let namespace: String?
}

// MARK: - ConfigMap

struct ConfigMap: KubernetesResource {
    static let apiPath = "/api/v1"
    static let kind = "configmaps"

    let metadata: ObjectMetadata
    let data: [String: String]?
    let binaryData: [String: String]?
}

// MARK: - Secret

struct Secret: KubernetesResource {
    static let apiPath = "/api/v1"
    static let kind = "secrets"

    let metadata: ObjectMetadata
    let type: String?
    let data: [String: String]?
}

// MARK: - Ingress

struct Ingress: KubernetesResource {
    static let apiPath = "/apis/networking.k8s.io/v1"
    static let kind = "ingresses"

    let metadata: ObjectMetadata
    let spec: IngressSpec?
    let status: IngressStatus?
}

struct IngressSpec: Decodable {
    let ingressClassName: String?
    let rules: [IngressRule]?
    let tls: [IngressTLS]?
}

struct IngressRule: Decodable {
    let host: String?
    let http: IngressHTTP?
}

struct IngressHTTP: Decodable {
    let paths: [IngressPath]?
}

struct IngressPath: Decodable {
    let path: String?
    let pathType: String?
    let backend: IngressBackend?
}

struct IngressBackend: Decodable {
    let service: IngressServiceBackend?
}

struct IngressServiceBackend: Decodable {
    let name: String?
    let port: IngressServicePort?
}

struct IngressServicePort: Decodable {
    let number: Int?
    let name: String?
}

struct IngressTLS: Decodable {
    let hosts: [String]?
    let secretName: String?
}

struct IngressStatus: Decodable {
    let loadBalancer: IngressLoadBalancer?
}

struct IngressLoadBalancer: Decodable {
    let ingress: [IngressLoadBalancerEntry]?
}

struct IngressLoadBalancerEntry: Decodable {
    let ip: String?
    let hostname: String?
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

// MARK: - StatefulSet Helpers

extension StatefulSet {
    var readyCount: String {
        "\(status?.readyReplicas ?? 0)/\(spec?.replicas ?? 0)"
    }

    var isReady: Bool {
        guard let replicas = spec?.replicas else { return false }
        return (status?.readyReplicas ?? 0) >= replicas
    }
}

// MARK: - DaemonSet Helpers

extension DaemonSet {
    var isReady: Bool {
        let desired = status?.desiredNumberScheduled ?? 0
        return desired > 0 && (status?.numberReady ?? 0) >= desired
    }
}

// MARK: - ReplicaSet Helpers

extension ReplicaSet {
    var readyCount: String {
        "\(status?.readyReplicas ?? 0)/\(spec?.replicas ?? 0)"
    }

    var isReady: Bool {
        guard let replicas = spec?.replicas, replicas > 0 else { return false }
        return (status?.readyReplicas ?? 0) >= replicas
    }
}

// MARK: - Job Helpers

extension Job {
    var isComplete: Bool {
        status?.conditions?.contains { $0.type == "Complete" && $0.status == "True" } ?? false
    }

    var isFailed: Bool {
        status?.conditions?.contains { $0.type == "Failed" && $0.status == "True" } ?? false
    }

    var completionCount: String {
        "\(status?.succeeded ?? 0)/\(spec?.completions ?? 1)"
    }

    var duration: String {
        guard let start = status?.startTime else { return "-" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let startDate = formatter.date(from: start)
            ?? ISO8601DateFormatter().date(from: start) else { return "-" }

        let end: Date
        if let completionTime = status?.completionTime,
           let endDate = formatter.date(from: completionTime)
            ?? ISO8601DateFormatter().date(from: completionTime)
        {
            end = endDate
        } else {
            end = Date()
        }

        let interval = end.timeIntervalSince(startDate)
        if interval < 60 { return "\(Int(interval))s" }
        if interval < 3600 { return "\(Int(interval / 60))m" }
        return "\(Int(interval / 3600))h\(Int(interval.truncatingRemainder(dividingBy: 3600) / 60))m"
    }
}

// MARK: - CronJob Helpers

extension CronJob {
    var isSuspended: Bool { spec?.suspend ?? false }
    var activeCount: Int { status?.active?.count ?? 0 }
}

// MARK: - Ingress Helpers

extension Ingress {
    var hosts: [String] {
        spec?.rules?.compactMap(\.host) ?? []
    }

    var addresses: [String] {
        status?.loadBalancer?.ingress?.compactMap { $0.ip ?? $0.hostname } ?? []
    }

    var hasTLS: Bool {
        spec?.tls != nil && !(spec?.tls?.isEmpty ?? true)
    }
}

// MARK: - ConfigMap Helpers

extension ConfigMap {
    var dataCount: Int { (data?.count ?? 0) + (binaryData?.count ?? 0) }
}

// MARK: - Secret Helpers

extension Secret {
    var dataCount: Int { data?.count ?? 0 }
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
