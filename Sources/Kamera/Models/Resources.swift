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
    var sortableNamespace: String { namespace ?? "" }
    var sortableAge: String { metadata.creationTimestamp ?? "" }
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

// MARK: - Service Helpers

extension Service {
    var sortableType: String { spec?.type ?? "" }
    var sortableClusterIP: String { spec?.clusterIP ?? "" }
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

// MARK: - PersistentVolume

struct PersistentVolume: KubernetesResource {
    static let apiPath = "/api/v1"
    static let kind = "persistentvolumes"

    let metadata: ObjectMetadata
    let spec: PersistentVolumeSpec?
    let status: PersistentVolumeStatus?
}

struct PersistentVolumeSpec: Decodable {
    let capacity: [String: String]?
    let accessModes: [String]?
    let persistentVolumeReclaimPolicy: String?
    let storageClassName: String?
    let claimRef: ClaimReference?
}

struct ClaimReference: Decodable {
    let name: String?
    let namespace: String?
}

struct PersistentVolumeStatus: Decodable {
    let phase: String?
}

// MARK: - PersistentVolumeClaim

struct PersistentVolumeClaim: KubernetesResource {
    static let apiPath = "/api/v1"
    static let kind = "persistentvolumeclaims"

    let metadata: ObjectMetadata
    let spec: PersistentVolumeClaimSpec?
    let status: PersistentVolumeClaimStatus?
}

struct PersistentVolumeClaimSpec: Decodable {
    let accessModes: [String]?
    let resources: ResourceRequirements?
    let storageClassName: String?
    let volumeName: String?
}

struct PersistentVolumeClaimStatus: Decodable {
    let phase: String?
    let capacity: [String: String]?
    let accessModes: [String]?
}

// MARK: - Event

struct Event: KubernetesResource {
    static let apiPath = "/api/v1"
    static let kind = "events"

    let metadata: ObjectMetadata
    let involvedObject: ObjectReference?
    let reason: String?
    let message: String?
    let source: EventSource?
    let type: String?
    let firstTimestamp: String?
    let lastTimestamp: String?
    let count: Int?
}

struct ObjectReference: Decodable {
    let kind: String?
    let name: String?
    let namespace: String?
    let uid: String?
}

struct EventSource: Decodable {
    let component: String?
    let host: String?
}

// MARK: - ResourceKind Mapping

extension ClusterViewModel.ResourceKind {
    var kubernetesKind: String {
        switch self {
        case .pods: return "Pod"
        case .deployments: return "Deployment"
        case .statefulSets: return "StatefulSet"
        case .daemonSets: return "DaemonSet"
        case .replicaSets: return "ReplicaSet"
        case .jobs: return "Job"
        case .cronJobs: return "CronJob"
        case .services: return "Service"
        case .ingresses: return "Ingress"
        case .configMaps: return "ConfigMap"
        case .secrets: return "Secret"
        case .nodes: return "Node"
        case .persistentVolumes: return "PersistentVolume"
        case .persistentVolumeClaims: return "PersistentVolumeClaim"
        case .events: return "Event"
        }
    }

    static func from(kubernetesKind: String) -> ClusterViewModel.ResourceKind? {
        switch kubernetesKind {
        case "Pod": return .pods
        case "Deployment": return .deployments
        case "StatefulSet": return .statefulSets
        case "DaemonSet": return .daemonSets
        case "ReplicaSet": return .replicaSets
        case "Job": return .jobs
        case "CronJob": return .cronJobs
        case "Service": return .services
        case "Ingress": return .ingresses
        case "ConfigMap": return .configMaps
        case "Secret": return .secrets
        case "Node": return .nodes
        case "PersistentVolume": return .persistentVolumes
        case "PersistentVolumeClaim": return .persistentVolumeClaims
        case "Event": return .events
        default: return nil
        }
    }
}

// MARK: - Event Helpers

extension Event {
    var sortableReason: String { reason ?? "" }
    var sortableCount: Int { count ?? 0 }
    var sortableType: String { type ?? "" }

    var isWarning: Bool { type == "Warning" }

    var involvedObjectDescription: String {
        guard let obj = involvedObject else { return "-" }
        return "\(obj.kind ?? "Unknown")/\(obj.name ?? "unknown")"
    }

    var age: String {
        formatAge(from: lastTimestamp ?? firstTimestamp ?? metadata.creationTimestamp)
    }
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

    var sortableStatus: String { statusText }
    var sortableNode: String { spec?.nodeName ?? "" }

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
    var sortableReady: Int { status?.readyReplicas ?? 0 }
    var sortableAvailable: Int { status?.availableReplicas ?? 0 }

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
    var sortableReady: Int { status?.readyReplicas ?? 0 }

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
    var sortableDesired: Int { status?.desiredNumberScheduled ?? 0 }
    var sortableReady: Int { status?.numberReady ?? 0 }

    var isReady: Bool {
        let desired = status?.desiredNumberScheduled ?? 0
        return desired > 0 && (status?.numberReady ?? 0) >= desired
    }
}

// MARK: - ReplicaSet Helpers

extension ReplicaSet {
    var sortableReady: Int { status?.readyReplicas ?? 0 }

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
    var sortableSucceeded: Int { status?.succeeded ?? 0 }

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
    var sortableSchedule: String { spec?.schedule ?? "" }
}

// MARK: - Ingress Helpers

extension Ingress {
    var sortableClass: String { spec?.ingressClassName ?? "" }

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
    var sortableType: String { type ?? "" }
    var dataCount: Int { data?.count ?? 0 }
}

// MARK: - Node Helpers

extension Node {
    var sortableVersion: String { kubeletVersion ?? "" }

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

// MARK: - PersistentVolume Helpers

extension PersistentVolume {
    var sortablePhase: String { status?.phase ?? "" }
    var sortableStorageClass: String { spec?.storageClassName ?? "" }

    var capacity: String {
        spec?.capacity?["storage"] ?? "-"
    }

    var isBound: Bool {
        status?.phase == "Bound"
    }

    var accessModesShort: String {
        spec?.accessModes?.map { abbreviateAccessMode($0) }.joined(separator: ",") ?? "-"
    }

    var statusBadge: StatusBadge.Status {
        switch status?.phase {
        case "Bound": return .healthy
        case "Available": return .pending
        case "Released": return .warning
        case "Failed": return .error
        default: return .unknown
        }
    }

    var claimDescription: String {
        guard let ref = spec?.claimRef else { return "-" }
        let ns = ref.namespace ?? ""
        let name = ref.name ?? ""
        return ns.isEmpty ? name : "\(ns)/\(name)"
    }
}

// MARK: - PersistentVolumeClaim Helpers

extension PersistentVolumeClaim {
    var sortablePhase: String { status?.phase ?? "" }
    var sortableStorageClass: String { spec?.storageClassName ?? "" }

    var isBound: Bool {
        status?.phase == "Bound"
    }

    var requestedStorage: String {
        spec?.resources?.requests?["storage"] ?? "-"
    }

    var actualCapacity: String {
        status?.capacity?["storage"] ?? "-"
    }

    var accessModesShort: String {
        let modes = status?.accessModes ?? spec?.accessModes ?? []
        if modes.isEmpty { return "-" }
        return modes.map { abbreviateAccessMode($0) }.joined(separator: ",")
    }

    var statusBadge: StatusBadge.Status {
        switch status?.phase {
        case "Bound": return .healthy
        case "Pending": return .pending
        case "Lost": return .error
        default: return .unknown
        }
    }
}

// MARK: - Access Mode Abbreviation

private func abbreviateAccessMode(_ mode: String) -> String {
    switch mode {
    case "ReadWriteOnce": return "RWO"
    case "ReadOnlyMany": return "ROX"
    case "ReadWriteMany": return "RWX"
    case "ReadWriteOncePod": return "RWOP"
    default: return mode
    }
}

// MARK: - Metrics Models

struct ResourceQuantities: Decodable {
    let cpu: String?    // e.g. "123m", "1500000000n", "2"
    let memory: String? // e.g. "512Ki", "256Mi", "1Gi"
}

struct ContainerMetrics: Decodable {
    let name: String
    let usage: ResourceQuantities
}

struct PodMetrics: KubernetesResource {
    static let apiPath = "/apis/metrics.k8s.io/v1beta1"
    static let kind    = "pods"
    let metadata: ObjectMetadata
    let containers: [ContainerMetrics]

    var totalCPUMillicores: Int {
        containers.compactMap { parseMillicores($0.usage.cpu) }.reduce(0, +)
    }
    var totalMemoryBytes: Int64 {
        containers.compactMap { parseMemoryBytes($0.usage.memory) }.reduce(0, +)
    }
}

struct NodeMetrics: KubernetesResource {
    static let apiPath = "/apis/metrics.k8s.io/v1beta1"
    static let kind    = "nodes"
    let metadata: ObjectMetadata
    let usage: ResourceQuantities

    var cpuMillicores: Int   { parseMillicores(usage.cpu) ?? 0 }
    var memoryBytes:   Int64 { parseMemoryBytes(usage.memory) ?? 0 }
}

// MARK: - Quantity Parsers & Formatters

func parseMillicores(_ s: String?) -> Int? {
    guard let s = s else { return nil }
    if s.hasSuffix("m") {
        return Int(s.dropLast())
    } else if s.hasSuffix("n") {
        guard let n = Int64(s.dropLast()) else { return nil }
        return Int(n / 1_000_000)
    } else if let cores = Double(s) {
        return Int(cores * 1000)
    }
    return nil
}

func parseMemoryBytes(_ s: String?) -> Int64? {
    guard let s = s else { return nil }
    let suffixes: [(String, Int64)] = [
        ("Ki", 1024),
        ("Mi", 1024 * 1024),
        ("Gi", 1024 * 1024 * 1024),
        ("Ti", 1024 * 1024 * 1024 * 1024),
        ("K", 1000),
        ("M", 1000 * 1000),
        ("G", 1000 * 1000 * 1000),
        ("T", 1000 * 1000 * 1000 * 1000),
    ]
    for (suffix, multiplier) in suffixes {
        if s.hasSuffix(suffix) {
            guard let value = Int64(s.dropLast(suffix.count)) else { return nil }
            return value * multiplier
        }
    }
    return Int64(s)
}

func formatMillicores(_ m: Int) -> String {
    if m < 1000 {
        return "\(m)m"
    }
    let cores = Double(m) / 1000.0
    if cores == Double(Int(cores)) {
        return "\(Int(cores))"
    }
    return String(format: "%.1f", cores)
}

func formatBytes(_ b: Int64) -> String {
    let units: [(String, Int64)] = [
        ("Ti", 1024 * 1024 * 1024 * 1024),
        ("Gi", 1024 * 1024 * 1024),
        ("Mi", 1024 * 1024),
        ("Ki", 1024),
    ]
    for (suffix, divisor) in units {
        if b >= divisor {
            let value = Double(b) / Double(divisor)
            if value == Double(Int(value)) {
                return "\(Int(value))\(suffix)"
            }
            return String(format: "%.1f", value) + suffix
        }
    }
    return "\(b)B"
}
