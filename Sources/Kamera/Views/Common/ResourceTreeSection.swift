import SwiftUI

// MARK: - ResourceTreeNode

struct ResourceTreeNode: Identifiable {
    let id: String
    let kind: String
    let name: String
    let status: StatusBadge.Status
    let children: [ResourceTreeNode]
}

// MARK: - FlatRow

private struct FlatRow: Identifiable {
    let node: ResourceTreeNode
    let depth: Int
    let isLast: Bool
    let ancestorIsLast: [Bool]

    var id: String { node.id }
}

// MARK: - ResourceTreeSection

struct ResourceTreeSection: View {
    let nodes: [ResourceTreeNode]

    @State private var expandedIDs: Set<String>

    init(nodes: [ResourceTreeNode]) {
        self.nodes = nodes
        var ids = Set<String>()
        func collectParents(_ nodes: [ResourceTreeNode]) {
            for node in nodes {
                if !node.children.isEmpty {
                    ids.insert(node.id)
                    collectParents(node.children)
                }
            }
        }
        collectParents(nodes)
        _expandedIDs = State(initialValue: ids)
    }

    private var flatRows: [FlatRow] {
        var rows: [FlatRow] = []
        flatten(nodes: nodes, depth: 0, ancestorIsLast: [], into: &rows)
        return rows
    }

    private func flatten(
        nodes: [ResourceTreeNode],
        depth: Int,
        ancestorIsLast: [Bool],
        into rows: inout [FlatRow]
    ) {
        for (index, node) in nodes.enumerated() {
            let isLast = index == nodes.count - 1
            rows.append(FlatRow(node: node, depth: depth, isLast: isLast, ancestorIsLast: ancestorIsLast))
            if !node.children.isEmpty && expandedIDs.contains(node.id) {
                flatten(
                    nodes: node.children,
                    depth: depth + 1,
                    ancestorIsLast: ancestorIsLast + [isLast],
                    into: &rows
                )
            }
        }
    }

    var body: some View {
        if !nodes.isEmpty {
            DetailSection(title: "Related Resources") {
                VStack(spacing: 0) {
                    ForEach(flatRows) { row in
                        ResourceTreeRow(
                            row: row,
                            isExpanded: expandedIDs.contains(row.node.id),
                            onToggle: {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    if expandedIDs.contains(row.node.id) {
                                        expandedIDs.remove(row.node.id)
                                    } else {
                                        expandedIDs.insert(row.node.id)
                                    }
                                }
                            }
                        )
                    }
                }
            }
        }
    }
}

// MARK: - ResourceTreeRow

private struct ResourceTreeRow: View {
    let row: FlatRow
    let isExpanded: Bool
    let onToggle: () -> Void

    private let indentWidth: CGFloat = 16

    var body: some View {
        HStack(spacing: 0) {
            ForEach(0..<row.depth, id: \.self) { level in
                ConnectorGutter(drawLine: !row.ancestorIsLast[level])
                    .frame(width: indentWidth)
            }

            OwnConnector(isLast: row.isLast)
                .frame(width: indentWidth)

            HStack(spacing: 6) {
                StatusBadge(status: row.node.status)

                Text(row.node.kind)
                    .font(.caption)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(.quaternary)
                    .clipShape(RoundedRectangle(cornerRadius: 4))

                ResourceLink(kind: row.node.kind, name: row.node.name)

                Spacer()

                if !row.node.children.isEmpty {
                    if !isExpanded {
                        Text("\(row.node.children.count)")
                            .font(.caption2)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(.quaternary)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                    }

                    Button(action: onToggle) {
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(isExpanded ? 90 : 0))
                            .animation(.easeInOut(duration: 0.2), value: isExpanded)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 3)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            if !row.node.children.isEmpty {
                onToggle()
            }
        }
    }
}

// MARK: - ConnectorGutter

private struct ConnectorGutter: View {
    let drawLine: Bool

    var body: some View {
        Canvas { context, size in
            guard drawLine else { return }
            var path = Path()
            path.move(to: CGPoint(x: size.width / 2, y: 0))
            path.addLine(to: CGPoint(x: size.width / 2, y: size.height))
            context.stroke(path, with: .color(Color.primary.opacity(0.15)), lineWidth: 1)
        }
    }
}

// MARK: - OwnConnector

private struct OwnConnector: View {
    let isLast: Bool

    var body: some View {
        Canvas { context, size in
            let midX = size.width / 2
            let midY = size.height / 2

            var path = Path()
            // Vertical: top to mid for L-shape (last), top to bottom for T-shape (non-last)
            path.move(to: CGPoint(x: midX, y: 0))
            path.addLine(to: CGPoint(x: midX, y: isLast ? midY : size.height))
            // Horizontal: center to right edge
            path.move(to: CGPoint(x: midX, y: midY))
            path.addLine(to: CGPoint(x: size.width, y: midY))

            context.stroke(path, with: .color(Color.primary.opacity(0.15)), lineWidth: 1)
        }
    }
}
