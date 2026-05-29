import Foundation

/// 管理写入 ~/.claude/settings.json 的 Claude Code hook。
///
/// 开启「检测 Claude Code 状态」时 install()，关闭时 uninstall()。
/// 安全原则：
/// - 只增删带 `Constants.claudeHookMarker` 标记的 entry，绝不触碰用户其它 hook/键。
/// - 写入前做带时间戳备份。
/// - 幂等：重复 install 不会堆叠重复 entry。
///
/// 已知权衡：JSONSerialization 重写会规整 settings.json 的格式与键序
/// （用户手工排版会被规整）。这是为了用系统自带能力安全地做结构化合并；
/// 已通过备份缓解，且仅在用户显式开关时才改动。
enum ClaudeHookManager {

    private static var settingsURL: URL {
        URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent(".claude/settings.json")
    }

    private static var needsConfirmCommand: String {
        let rel = Constants.claudeEventsRelativePath
        return "mkdir -p \"$HOME/\(rel)\" && mktemp \"$HOME/\(rel)/\(Constants.claudeEventNeedsConfirm).XXXXXX\" >/dev/null 2>&1 \(Constants.claudeHookMarker)"
    }

    private static var doneCommand: String {
        let rel = Constants.claudeEventsRelativePath
        return "mkdir -p \"$HOME/\(rel)\" && mktemp \"$HOME/\(rel)/\(Constants.claudeEventDone).XXXXXX\" >/dev/null 2>&1 \(Constants.claudeHookMarker)"
    }

    // MARK: - 公开接口

    static func install() {
        var settings = loadSettings()
        var hooks = (settings["hooks"] as? [String: Any]) ?? [:]

        hooks["Notification"] = ensureEntry(
            in: hooks["Notification"] as? [[String: Any]] ?? [],
            matcher: "permission_prompt",
            command: needsConfirmCommand)
        hooks["Stop"] = ensureEntry(
            in: hooks["Stop"] as? [[String: Any]] ?? [],
            matcher: nil,
            command: doneCommand)

        settings["hooks"] = hooks
        save(settings)
    }

    static func uninstall() {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }
        var settings = loadSettings()
        guard var hooks = settings["hooks"] as? [String: Any] else { return }

        for event in ["Notification", "Stop"] {
            guard let groups = hooks[event] as? [[String: Any]] else { continue }
            let kept = groups.filter { !groupContainsMarker($0) }
            if kept.isEmpty { hooks.removeValue(forKey: event) }
            else { hooks[event] = kept }
        }

        if hooks.isEmpty { settings.removeValue(forKey: "hooks") }
        else { settings["hooks"] = hooks }
        save(settings)
    }

    // MARK: - 结构操作

    /// 若 groups 中尚无带标记的 entry，追加一个；否则原样返回（幂等）。
    private static func ensureEntry(
        in groups: [[String: Any]], matcher: String?, command: String
    ) -> [[String: Any]] {
        if groups.contains(where: groupContainsMarker) { return groups }
        var group: [String: Any] = ["hooks": [["type": "command", "command": command]]]
        if let matcher { group["matcher"] = matcher }
        return groups + [group]
    }

    private static func groupContainsMarker(_ group: [String: Any]) -> Bool {
        guard let hooks = group["hooks"] as? [[String: Any]] else { return false }
        return hooks.contains { ($0["command"] as? String)?.contains(Constants.claudeHookMarker) == true }
    }

    // MARK: - 读写

    private static func loadSettings() -> [String: Any] {
        guard let data = try? Data(contentsOf: settingsURL),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return [:] }
        return json
    }

    private static func save(_ settings: [String: Any]) {
        backupIfPresent()
        do {
            try FileManager.default.createDirectory(
                at: settingsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            let data = try JSONSerialization.data(
                withJSONObject: settings, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: settingsURL, options: .atomic)
        } catch {
            print("[TerminalNotifier] 写入 settings.json 失败: \(error)")
        }
    }

    private static func backupIfPresent() {
        guard FileManager.default.fileExists(atPath: settingsURL.path) else { return }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyyMMdd-HHmmss"
        let backup = settingsURL.deletingLastPathComponent()
            .appendingPathComponent("settings.json.tn-backup-\(fmt.string(from: Date()))")
        try? FileManager.default.copyItem(at: settingsURL, to: backup)
    }
}
