import Foundation

/// 管理写入 ~/.codex/hooks.json 的 Codex hook。
///
/// 开启「检测 Codex 状态」时 install()，关闭时 uninstall()。
/// 只增删带 `Constants.codexHookMarker` 标记的 entry，保留用户其它 hook。
enum CodexHookManager {

    private static var hooksURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".codex/hooks.json")
    }

    private static var needsConfirmCommand: String {
        let rel = Constants.codexEventsRelativePath
        let log = Constants.codexHookLogRelativePath
        return "mkdir -p \"$HOME/\(rel)\"; date '+needs_confirm %Y-%m-%d %H:%M:%S' >> \"$HOME/\(log)\"; mktemp \"$HOME/\(rel)/\(Constants.claudeEventNeedsConfirm).XXXXXX\" >/dev/null 2>&1 \(Constants.codexHookMarker)"
    }

    private static var doneCommand: String {
        let rel = Constants.codexEventsRelativePath
        let log = Constants.codexHookLogRelativePath
        return "mkdir -p \"$HOME/\(rel)\"; date '+done %Y-%m-%d %H:%M:%S' >> \"$HOME/\(log)\"; mktemp \"$HOME/\(rel)/\(Constants.claudeEventDone).XXXXXX\" >/dev/null 2>&1 \(Constants.codexHookMarker)"
    }

    @discardableResult
    static func install() -> Bool {
        guard var settings = loadSettings() else { return false }
        guard var hooks = loadHooks(from: settings) else { return false }
        guard let permissionGroups = loadHookGroups(from: hooks, event: "PermissionRequest"),
              let stopGroups = loadHookGroups(from: hooks, event: "Stop") else {
            return false
        }

        hooks["PermissionRequest"] = ensureEntry(in: permissionGroups, command: needsConfirmCommand)
        hooks["Stop"] = ensureEntry(in: stopGroups, command: doneCommand)
        settings["hooks"] = hooks
        return save(settings)
    }

    @discardableResult
    static func uninstall() -> Bool {
        guard FileManager.default.fileExists(atPath: hooksURL.path) else { return true }
        guard var settings = loadSettings() else { return false }
        guard settings["hooks"] != nil else { return true }
        guard var hooks = loadHooks(from: settings) else { return false }

        for event in ["PermissionRequest", "Stop"] {
            guard let groups = loadHookGroups(from: hooks, event: event) else { return false }
            if groups.isEmpty, hooks[event] == nil { continue }
            let kept = groups.filter { !groupContainsMarker($0) }
            if kept.isEmpty { hooks.removeValue(forKey: event) }
            else { hooks[event] = kept }
        }

        if hooks.isEmpty { settings.removeValue(forKey: "hooks") }
        else { settings["hooks"] = hooks }
        return save(settings)
    }

    private static func ensureEntry(in groups: [[String: Any]], command: String) -> [[String: Any]] {
        let group: [String: Any] = ["hooks": [["type": "command", "command": command]]]
        let kept = groups.filter { !groupContainsMarker($0) }
        return kept + [group]
    }

    private static func groupContainsMarker(_ group: [String: Any]) -> Bool {
        guard let hooks = group["hooks"] as? [[String: Any]] else { return false }
        return hooks.contains { ($0["command"] as? String)?.contains(Constants.codexHookMarker) == true }
    }

    private static func loadSettings() -> [String: Any]? {
        guard FileManager.default.fileExists(atPath: hooksURL.path) else { return [:] }

        do {
            let data = try Data(contentsOf: hooksURL)
            guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                print("[TerminalNotifier] hooks.json 顶层不是 JSON object，已取消写入: \(hooksURL.path)")
                return nil
            }
            return json
        } catch {
            print("[TerminalNotifier] 读取 hooks.json 失败，已取消写入: \(error)")
            return nil
        }
    }

    private static func loadHooks(from settings: [String: Any]) -> [String: Any]? {
        guard let hooks = settings["hooks"] else { return [:] }
        guard let hooks = hooks as? [String: Any] else {
            print("[TerminalNotifier] hooks.json 中 hooks 不是 JSON object，已取消写入")
            return nil
        }
        return hooks
    }

    private static func loadHookGroups(from hooks: [String: Any], event: String) -> [[String: Any]]? {
        guard let groups = hooks[event] else { return [] }
        guard let groups = groups as? [[String: Any]] else {
            print("[TerminalNotifier] hooks.json 中 hooks.\(event) 不是 hook group array，已取消写入")
            return nil
        }
        return groups
    }

    private static func save(_ settings: [String: Any]) -> Bool {
        guard backupIfPresent() else { return false }
        do {
            try FileManager.default.createDirectory(
                at: hooksURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONSerialization.data(
                withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: hooksURL, options: .atomic)
            return true
        } catch {
            print("[TerminalNotifier] 写入 hooks.json 失败: \(error)")
            return false
        }
    }

    private static func backupIfPresent() -> Bool {
        guard FileManager.default.fileExists(atPath: hooksURL.path) else { return true }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        let backup = availableBackupURL(timestamp: fmt.string(from: Date()))
        do {
            try FileManager.default.copyItem(at: hooksURL, to: backup)
            return true
        } catch {
            print("[TerminalNotifier] 备份 hooks.json 失败，已取消写入: \(error)")
            return false
        }
    }

    private static func availableBackupURL(timestamp: String) -> URL {
        let directory = hooksURL.deletingLastPathComponent()
        let baseName = "hooks.json.tn-backup-\(timestamp)"
        var candidate = directory.appendingPathComponent(baseName)
        var suffix = 2
        while FileManager.default.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(baseName)-\(suffix)")
            suffix += 1
        }
        return candidate
    }
}
