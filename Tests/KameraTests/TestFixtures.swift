import Foundation
@testable import Kamera

// MARK: - JSON Decode Helper

func decode<T: Decodable>(_ json: String) -> T {
    let data = json.data(using: .utf8)!
    return try! JSONDecoder().decode(T.self, from: data)
}

// MARK: - Pod Fixture

func makePod(
    name: String = "test-pod",
    namespace: String = "default",
    uid: String = "pod-uid-1",
    phase: String = "Running",
    containerCount: Int = 1,
    readyContainers: Int? = nil,
    restarts: [Int]? = nil,
    nodeName: String? = nil,
    ownerUID: String? = nil
) -> Pod {
    let readyCount = readyContainers ?? containerCount
    let restartCounts = restarts ?? Array(repeating: 0, count: containerCount)

    var ownerRefsJSON = ""
    if let ownerUID {
        ownerRefsJSON = """
        , "ownerReferences": [{"apiVersion": "apps/v1", "kind": "ReplicaSet", "name": "owner", "uid": "\(ownerUID)"}]
        """
    }

    let containers = (0..<containerCount).map { i in
        """
        {"name": "container-\(i)", "image": "nginx"}
        """
    }.joined(separator: ", ")

    var nodeJSON = ""
    if let nodeName {
        nodeJSON = ", \"nodeName\": \"\(nodeName)\""
    }

    var containerStatusesJSON = ""
    if containerCount > 0 {
        let statuses = (0..<containerCount).map { i in
            let ready = i < readyCount
            let rc = i < restartCounts.count ? restartCounts[i] : 0
            return """
            {"name": "container-\(i)", "ready": \(ready), "restartCount": \(rc), "image": "nginx"}
            """
        }.joined(separator: ", ")
        containerStatusesJSON = ", \"containerStatuses\": [\(statuses)]"
    }

    let json = """
    {
        "metadata": {"name": "\(name)", "namespace": "\(namespace)", "uid": "\(uid)", "creationTimestamp": "2025-01-01T00:00:00Z"\(ownerRefsJSON)},
        "spec": {"containers": [\(containers)]\(nodeJSON)},
        "status": {"phase": "\(phase)"\(containerStatusesJSON)}
    }
    """
    return decode(json)
}

// MARK: - Deployment Fixture

func makeDeployment(
    name: String = "test-deploy",
    namespace: String = "default",
    uid: String = "deploy-uid-1",
    replicas: Int? = 3,
    availableReplicas: Int? = nil,
    readyReplicas: Int? = nil
) -> Deployment {
    var specJSON = "null"
    var statusJSON = "{}"

    if let replicas {
        let available = availableReplicas ?? replicas
        let ready = readyReplicas ?? replicas
        specJSON = "{\"replicas\": \(replicas)}"
        statusJSON = "{\"replicas\": \(replicas), \"readyReplicas\": \(ready), \"availableReplicas\": \(available)}"
    }

    let json = """
    {
        "metadata": {"name": "\(name)", "namespace": "\(namespace)", "uid": "\(uid)", "creationTimestamp": "2025-01-01T00:00:00Z"},
        "spec": \(specJSON),
        "status": \(statusJSON)
    }
    """
    return decode(json)
}

// MARK: - Job Fixture

func makeJob(
    name: String = "test-job",
    namespace: String = "default",
    uid: String = "job-uid-1",
    completions: Int = 1,
    succeeded: Int = 0,
    isComplete: Bool = false,
    isFailed: Bool = false,
    ownerUID: String? = nil
) -> Job {
    var conditions: [String] = []
    if isComplete {
        conditions.append("{\"type\": \"Complete\", \"status\": \"True\"}")
    }
    if isFailed {
        conditions.append("{\"type\": \"Failed\", \"status\": \"True\"}")
    }

    var ownerRefsJSON = ""
    if let ownerUID {
        ownerRefsJSON = """
        , "ownerReferences": [{"apiVersion": "batch/v1", "kind": "CronJob", "name": "owner", "uid": "\(ownerUID)"}]
        """
    }

    let conditionsJSON = conditions.isEmpty ? "" : ", \"conditions\": [\(conditions.joined(separator: ", "))]"

    let json = """
    {
        "metadata": {"name": "\(name)", "namespace": "\(namespace)", "uid": "\(uid)", "creationTimestamp": "2025-01-01T00:00:00Z"\(ownerRefsJSON)},
        "spec": {"completions": \(completions)},
        "status": {"succeeded": \(succeeded)\(conditionsJSON)}
    }
    """
    return decode(json)
}

// MARK: - Node Fixture

func makeNode(
    name: String = "test-node",
    uid: String = "node-uid-1",
    isReady: Bool = true,
    kubeletVersion: String = "v1.28.0"
) -> Node {
    let readyStatus = isReady ? "True" : "False"
    let json = """
    {
        "metadata": {"name": "\(name)", "uid": "\(uid)", "creationTimestamp": "2025-01-01T00:00:00Z"},
        "status": {
            "conditions": [{"type": "Ready", "status": "\(readyStatus)"}],
            "nodeInfo": {"kubeletVersion": "\(kubeletVersion)"}
        }
    }
    """
    return decode(json)
}

// MARK: - Event Fixture

func makeEvent(
    name: String = "test-event",
    namespace: String = "default",
    type: String = "Normal",
    reason: String = "Scheduled",
    count: Int = 1
) -> Event {
    let json = """
    {
        "metadata": {"name": "\(name)", "namespace": "\(namespace)", "creationTimestamp": "2025-01-01T00:00:00Z"},
        "type": "\(type)",
        "reason": "\(reason)",
        "count": \(count)
    }
    """
    return decode(json)
}

// MARK: - ReplicaSet Fixture

func makeReplicaSet(
    name: String = "test-rs",
    namespace: String = "default",
    uid: String = "rs-uid-1",
    replicas: Int = 3,
    readyReplicas: Int? = nil,
    ownerUID: String? = nil
) -> ReplicaSet {
    let ready = readyReplicas ?? replicas

    var ownerRefsJSON = ""
    if let ownerUID {
        ownerRefsJSON = """
        , "ownerReferences": [{"apiVersion": "apps/v1", "kind": "Deployment", "name": "owner", "uid": "\(ownerUID)"}]
        """
    }

    let json = """
    {
        "metadata": {"name": "\(name)", "namespace": "\(namespace)", "uid": "\(uid)", "creationTimestamp": "2025-01-01T00:00:00Z"\(ownerRefsJSON)},
        "spec": {"replicas": \(replicas)},
        "status": {"replicas": \(replicas), "readyReplicas": \(ready)}
    }
    """
    return decode(json)
}

// MARK: - PodMetrics Fixture

func makePodMetrics(
    name: String = "test-pod",
    namespace: String = "default",
    cpuMillicores: Int = 100,
    memoryKi: Int = 512
) -> PodMetrics {
    let json = """
    {
        "metadata": {"name": "\(name)", "namespace": "\(namespace)", "creationTimestamp": "2025-01-01T00:00:00Z"},
        "containers": [
            {"name": "main", "usage": {"cpu": "\(cpuMillicores)m", "memory": "\(memoryKi)Ki"}}
        ]
    }
    """
    return decode(json)
}

// MARK: - NodeMetrics Fixture

func makeNodeMetrics(
    name: String = "test-node",
    cpuMillicores: Int = 500,
    memoryKi: Int = 2048
) -> NodeMetrics {
    let json = """
    {
        "metadata": {"name": "\(name)", "creationTimestamp": "2025-01-01T00:00:00Z"},
        "usage": {"cpu": "\(cpuMillicores)m", "memory": "\(memoryKi)Ki"}
    }
    """
    return decode(json)
}

// MARK: - CronJob Fixture

func makeCronJob(
    name: String = "test-cronjob",
    namespace: String = "default",
    uid: String = "cj-uid-1",
    schedule: String = "*/5 * * * *",
    suspend: Bool = false
) -> CronJob {
    let json = """
    {
        "metadata": {"name": "\(name)", "namespace": "\(namespace)", "uid": "\(uid)", "creationTimestamp": "2025-01-01T00:00:00Z"},
        "spec": {"schedule": "\(schedule)", "suspend": \(suspend)}
    }
    """
    return decode(json)
}
