import Foundation

struct MessageProvider {

    enum Category: String, Codable {
        case newNotification = "new_notification"
        case longWait = "long_wait"
        case merged = "merged"
        case needsConfirm = "needs_confirm"
        case done = "done"
    }

    private let messages: [String: [String: Any]]

    init() {
        var loaded: [String: [String: Any]] = [:]
        for locale in ["zh", "en"] {
            if let data = Self.loadJSON(for: locale) {
                loaded[locale] = data
            }
        }
        self.messages = loaded
    }

    func randomMessage(category: Category, locale: String) -> String {
        let loc = messages[locale] ?? messages["en"] ?? [:]
        guard let list = loc[category.rawValue] as? [String], !list.isEmpty else {
            return fallbackMessage(category: category, locale: locale)
        }
        return list[Int.random(in: 0..<list.count)]
    }

    func mergedMessage(count: Int, locale: String) -> String {
        let loc = messages[locale] ?? messages["en"] ?? [:]
        guard let template = loc[Category.merged.rawValue] as? String else {
            return locale == "zh"
                ? "你有 \(count) 条终端通知"
                : "You have \(count) terminal notifications"
        }
        return template.replacingOccurrences(of: "{count}", with: String(count))
    }

    private func fallbackMessage(category: Category, locale: String) -> String {
        switch category {
        case .newNotification:
            return locale == "zh" ? "终端有通知啦！" : "Terminal notification!"
        case .longWait:
            return locale == "zh" ? "该看终端了！" : "Check your terminal!"
        case .merged:
            return locale == "zh" ? "有多条通知" : "Multiple notifications"
        case .needsConfirm:
            return locale == "zh" ? "Claude 需要你确认！" : "Claude needs your confirmation!"
        case .done:
            return locale == "zh" ? "Claude 说完啦！" : "Claude is done!"
        }
    }

    private static func loadJSON(for locale: String) -> [String: Any]? {
        let fileName = "messages_\(locale)"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json") else {
            // Fallback: look in same directory as executable (for dev builds)
            let altPath = URL(fileURLWithPath: Bundle.main.bundlePath)
                .deletingLastPathComponent().deletingLastPathComponent()
                .appendingPathComponent("TerminalNotifier/Messages/\(fileName).json")
            guard let data = try? Data(contentsOf: altPath),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                return nil
            }
            return json
        }
        guard let data = try? Data(contentsOf: url),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return json
    }
}
