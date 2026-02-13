import SwiftUI

// MARK: - Status Badge

struct StatusBadge: View {
    let status: Status

    enum Status {
        case healthy
        case warning
        case error
        case pending
        case unknown

        var color: Color {
            switch self {
            case .healthy: return .green
            case .warning: return .orange
            case .error: return .red
            case .pending: return .yellow
            case .unknown: return .gray
            }
        }

        var icon: String {
            switch self {
            case .healthy: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .pending: return "clock.fill"
            case .unknown: return "questionmark.circle.fill"
            }
        }
    }

    var body: some View {
        Image(systemName: status.icon)
            .foregroundStyle(status.color)
            .font(.caption)
    }
}

// MARK: - Pod Status Mapping

extension Pod {
    var statusBadge: StatusBadge.Status {
        switch phase {
        case .running where isReady:
            return .healthy
        case .running:
            return .warning
        case .succeeded:
            return .healthy
        case .pending:
            return .pending
        case .failed:
            return .error
        case .unknown:
            return .unknown
        }
    }
}

// MARK: - Age Formatter

func formatAge(from timestamp: String?) -> String {
    guard let timestamp = timestamp else { return "-" }

    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let date = formatter.date(from: timestamp) else {
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        guard let date = formatter.date(from: timestamp) else { return "-" }
        return relativeTime(from: date)
    }
    return relativeTime(from: date)
}

private func relativeTime(from date: Date) -> String {
    let interval = Date().timeIntervalSince(date)
    if interval < 60 { return "\(Int(interval))s" }
    if interval < 3600 { return "\(Int(interval / 60))m" }
    if interval < 86400 { return "\(Int(interval / 3600))h" }
    return "\(Int(interval / 86400))d"
}
