import SwiftUI

// MARK: - ResourceTreeNode

struct ResourceTreeNode: Identifiable {
    let id: String
    let kind: String
    let name: String
    let status: StatusBadge.Status
    let children: [ResourceTreeNode]
}

// MARK: - ResourceTreeSection

struct ResourceTreeSection: View {
    let nodes: [ResourceTreeNode]

    var body: some View {
        if !nodes.isEmpty {
            DetailSection(title: "Related Resources") {
                ForEach(nodes) { node in
                    ResourceTreeNodeView(node: node)
                }
            }
        }
    }
}

// MARK: - ResourceTreeNodeView

struct ResourceTreeNodeView: View {
    let node: ResourceTreeNode

    var body: some View {
        if node.children.isEmpty {
            ResourceTreeLeafRow(node: node)
        } else {
            DisclosureGroup {
                ForEach(node.children) { child in
                    ResourceTreeNodeView(node: child)
                }
            } label: {
                ResourceTreeLeafRow(node: node, childCount: node.children.count)
            }
        }
    }
}

// MARK: - ResourceTreeLeafRow

struct ResourceTreeLeafRow: View {
    let node: ResourceTreeNode
    var childCount: Int? = nil

    private var kindIcon: String {
        switch node.kind {
        case "Pod": return "cube"
        case "ReplicaSet": return "square.on.square"
        case "Job": return "gearshape"
        default: return "cube"
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            StatusBadge(status: node.status)
            Image(systemName: kindIcon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(node.kind)
                .font(.caption)
                .foregroundStyle(.secondary)
            ResourceLink(kind: node.kind, name: node.name)
            if let count = childCount {
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
            }
            Spacer()
        }
        .padding(.vertical, 1)
    }
}
