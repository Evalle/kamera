import SwiftUI

@main
struct KameraApp: App {
    @State private var viewModel = ClusterViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .frame(minWidth: 800, minHeight: 500)
        }
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh Resources") {
                    Task { await viewModel.refreshResources() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!viewModel.isConnected)
            }
            CommandMenu("Navigate") {
                Button("Quick Search") {
                    viewModel.isQuickSearchPresented.toggle()
                }
                .keyboardShortcut("k", modifiers: .command)
                .disabled(!viewModel.isConnected)
                Divider()
                Button("Previous Resource Kind") {
                    viewModel.selectPreviousResource()
                }
                .keyboardShortcut(.upArrow, modifiers: .command)
                .disabled(!viewModel.isConnected)
                Button("Next Resource Kind") {
                    viewModel.selectNextResource()
                }
                .keyboardShortcut(.downArrow, modifiers: .command)
                .disabled(!viewModel.isConnected)
            }
        }
        .windowStyle(.titleBar)
        .defaultSize(width: 1100, height: 700)
    }
}
