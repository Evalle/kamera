import SwiftUI

// MARK: - Appearance

enum AppearanceMode: Int, CaseIterable {
    case system = 0
    case light  = 1
    case dark   = 2

    var label: String {
        switch self {
        case .system: return "System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - App

@main
struct KameraApp: App {
    @State private var viewModel = ClusterViewModel()
    @State private var portForwardManager = PortForwardManager()
    @AppStorage("appearanceMode") private var appearanceMode: AppearanceMode = .system

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(viewModel)
                .environment(portForwardManager)
                .preferredColorScheme(appearanceMode.colorScheme)
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

        Settings {
            SettingsView()
                .environment(viewModel)
                .environment(portForwardManager)
        }
    }
}
