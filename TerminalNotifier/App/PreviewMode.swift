import Foundation

enum PreviewMode: String {
    case settings
    case history
    case overlay
    case all

    static var current: PreviewMode? {
        let args = CommandLine.arguments
        if let index = args.firstIndex(of: "--preview"),
           args.indices.contains(index + 1),
           let mode = PreviewMode(rawValue: args[index + 1]) {
            return mode
        }

        let env = ProcessInfo.processInfo.environment
        if env["TERMINAL_NOTIFIER_PREVIEW"] == "1" {
            return PreviewMode(rawValue: env["TERMINAL_NOTIFIER_PREVIEW_MODE"] ?? "settings") ?? .settings
        }

        return nil
    }
}
