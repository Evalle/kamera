import Foundation
import SwiftUI

// MARK: - PortForwardManager

@MainActor
@Observable
final class PortForwardManager {

    // MARK: - Forward Model

    struct Forward: Identifiable {
        let id: UUID
        let context: String
        let resourceType: ResourceType
        let resourceName: String
        let namespace: String
        let localPort: Int
        let remotePort: Int
        var status: Status

        enum ResourceType: String {
            case pod
            case service = "svc"

            var displayName: String {
                switch self {
                case .pod: return "Pod"
                case .service: return "Service"
                }
            }
        }

        enum Status: Equatable {
            case starting
            case active
            case failed(String)
        }

        var localURL: URL? {
            URL(string: "http://localhost:\(localPort)")
        }

        var displayTitle: String {
            "\(resourceType.displayName)/\(resourceName)"
        }

        var portMapping: String {
            "\(localPort) → \(remotePort)"
        }
    }

    // MARK: - State

    var forwards: [Forward] = []

    var activeCount: Int {
        forwards.filter { $0.status == .active }.count
    }

    // Keyed by Forward.id — stored outside the struct to avoid Observation overhead
    private var processes: [UUID: Process] = [:]

    // MARK: - Start

    func startForward(
        context: String,
        resourceType: Forward.ResourceType,
        resourceName: String,
        namespace: String,
        localPort: Int,
        remotePort: Int
    ) async {
        let id = UUID()
        forwards.append(Forward(
            id: id,
            context: context,
            resourceType: resourceType,
            resourceName: resourceName,
            namespace: namespace,
            localPort: localPort,
            remotePort: remotePort,
            status: .starting
        ))

        guard let kubectlPath = await findKubectl() else {
            setStatus(id: id, status: .failed("kubectl not found. Install it with: brew install kubectl"))
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: kubectlPath)
        process.arguments = [
            "port-forward",
            "--context", context,
            "--namespace", namespace,
            "\(resourceType.rawValue)/\(resourceName)",
            "\(localPort):\(remotePort)"
        ]

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        processes[id] = process

        // Monitor stdout: kubectl prints "Forwarding from 127.0.0.1:PORT" when ready
        outPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8),
                  text.contains("Forwarding from") else { return }
            Task { @MainActor [weak self] in
                self?.setStatus(id: id, status: .active)
            }
        }

        // Monitor stderr: surface kubectl error messages
        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty, let text = String(data: data, encoding: .utf8) else { return }
            let msg = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !msg.isEmpty else { return }
            Task { @MainActor [weak self] in
                self?.setStatus(id: id, status: .failed(msg))
            }
        }

        // Handle process exit
        process.terminationHandler = { _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.processes.removeValue(forKey: id)
                guard let idx = self.forwards.firstIndex(where: { $0.id == id }) else { return }
                // Only overwrite if not already in a terminal state
                if case .failed = self.forwards[idx].status { return }
                if self.forwards[idx].status != .starting {
                    self.forwards[idx].status = .failed("Process exited")
                } else {
                    self.forwards[idx].status = .failed("Could not start port forward")
                }
            }
        }

        do {
            try process.run()
        } catch {
            setStatus(id: id, status: .failed(error.localizedDescription))
            processes.removeValue(forKey: id)
        }
    }

    // MARK: - Stop

    func stopForward(id: UUID) {
        processes[id]?.terminate()
        processes.removeValue(forKey: id)
        forwards.removeAll { $0.id == id }
    }

    func stopAll() {
        for process in processes.values { process.terminate() }
        processes.removeAll()
        forwards.removeAll()
    }

    // MARK: - Helpers

    private func setStatus(id: UUID, status: Forward.Status) {
        guard let idx = forwards.firstIndex(where: { $0.id == id }) else { return }
        forwards[idx].status = status
    }

    private nonisolated func findKubectl() async -> String? {
        // 1. Ask the login shell — respects the user's PATH (e.g. asdf, mise, nix)
        let shellPath: String? = await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = Shell.loginShellURL
            process.arguments = ["-l", "-c", "which kubectl"]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()
            do {
                try process.run()
                process.waitUntilExit()
                if process.terminationStatus == 0 {
                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    let path = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    continuation.resume(returning: path.isEmpty ? nil : path)
                    return
                }
            } catch {}
            continuation.resume(returning: nil)
        }
        if let path = shellPath { return path }

        // 2. Common install locations as fallback
        let candidates = [
            "/opt/homebrew/bin/kubectl",  // Homebrew on Apple Silicon
            "/usr/local/bin/kubectl",     // Homebrew on Intel
            "/usr/bin/kubectl",
        ]
        return candidates.first { FileManager.default.fileExists(atPath: $0) }
    }
}
