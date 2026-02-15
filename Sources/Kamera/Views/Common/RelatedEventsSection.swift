import SwiftUI

struct RelatedEventsSection: View {
    @Environment(ClusterViewModel.self) private var viewModel
    let resourceKind: String
    let resourceName: String

    private var matchingEvents: [Event] {
        viewModel.events.filter {
            $0.involvedObject?.kind == resourceKind && $0.involvedObject?.name == resourceName
        }
    }

    var body: some View {
        if !matchingEvents.isEmpty {
            DetailSection(title: "Events") {
                ForEach(matchingEvents) { event in
                    HStack(spacing: 6) {
                        Image(systemName: event.isWarning ? "exclamationmark.triangle.fill" : "info.circle.fill")
                            .foregroundStyle(event.isWarning ? .orange : .blue)
                            .font(.caption)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(event.reason ?? "Unknown")
                                .font(.callout)
                                .fontWeight(.medium)
                            if let message = event.message {
                                Text(message)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        Spacer()
                        Text(event.age)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                }
            }
        }
    }
}
