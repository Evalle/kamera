import Foundation

/// Resolves the user's login shell so exec plugins find commands on the full PATH.
enum Shell {
    /// URL of the user's login shell (from `$SHELL`), defaults to `/bin/zsh`.
    static var loginShellURL: URL {
        let path = ProcessInfo.processInfo.environment["SHELL"] ?? "/bin/zsh"
        return URL(fileURLWithPath: path)
    }
}
