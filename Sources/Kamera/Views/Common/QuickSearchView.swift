import SwiftUI

struct QuickSearchView: View {
    @Environment(ClusterViewModel.self) private var viewModel
    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isTextFieldFocused: Bool

    private var results: [ClusterViewModel.SearchResult] {
        viewModel.searchAllResources(query: query)
    }

    private var groupedResults: [(kind: ClusterViewModel.ResourceKind, items: [ClusterViewModel.SearchResult])] {
        let grouped = Dictionary(grouping: results) { $0.kind }
        return ClusterViewModel.ResourceKind.allCases.compactMap { kind in
            guard let items = grouped[kind], !items.isEmpty else { return nil }
            return (kind: kind, items: items)
        }
    }

    private var flatResults: [ClusterViewModel.SearchResult] {
        groupedResults.flatMap(\.items)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search all resources...", text: $query)
                    .textFieldStyle(.plain)
                    .focused($isTextFieldFocused)
                    .onSubmit { selectCurrentResult() }
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .font(.title3)
            .padding(12)

            if !query.isEmpty {
                Divider()

                if flatResults.isEmpty {
                    Text("No results found")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 24)
                } else {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(groupedResults, id: \.kind) { group in
                                Section(group.kind.rawValue) {
                                    ForEach(group.items) { result in
                                        let index = flatResults.firstIndex(where: { $0.id == result.id }) ?? 0
                                        resultRow(result, isSelected: index == selectedIndex)
                                            .id(result.id)
                                            .onTapGesture { select(result) }
                                    }
                                }
                            }
                        }
                        .listStyle(.plain)
                        .onChange(of: selectedIndex) { _, newIndex in
                            if newIndex < flatResults.count {
                                proxy.scrollTo(flatResults[newIndex].id, anchor: .center)
                            }
                        }
                    }
                    .frame(maxHeight: 340)
                }
            }
        }
        .frame(width: 480)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(.quaternary, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 20, y: 10)
        .onAppear {
            isTextFieldFocused = true
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            if selectedIndex < flatResults.count - 1 { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            viewModel.isQuickSearchPresented = false
            return .handled
        }
    }

    private func resultRow(_ result: ClusterViewModel.SearchResult, isSelected: Bool) -> some View {
        HStack(spacing: 8) {
            Image(systemName: result.icon)
                .frame(width: 20)
                .foregroundStyle(.secondary)
            Text(result.name)
                .lineLimit(1)
            Spacer()
            if let ns = result.namespace {
                Text(ns)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.fill.tertiary, in: Capsule())
            }
        }
        .padding(.vertical, 2)
        .listRowBackground(
            isSelected ? Color.accentColor.opacity(0.15) : Color.clear
        )
    }

    private func selectCurrentResult() {
        guard !flatResults.isEmpty, selectedIndex < flatResults.count else { return }
        select(flatResults[selectedIndex])
    }

    private func select(_ result: ClusterViewModel.SearchResult) {
        viewModel.navigateTo(kind: result.kind.kubernetesKind, name: result.name)
        viewModel.isQuickSearchPresented = false
    }
}
