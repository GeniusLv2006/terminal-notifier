import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: PreferencesManager

    var body: some View {
        TabView {
            GeneralSettingsTab(preferences: preferences)
                .tabItem {
                    Label(settingsLang("General", zh: "通用"), systemImage: "gear")
                }
            NotificationSettingsTab(preferences: preferences)
                .tabItem {
                    Label(settingsLang("Notifications", zh: "通知"), systemImage: "bell")
                }
        }
        .frame(width: 450, height: 360)
    }
}

// MARK: - General Tab

struct GeneralSettingsTab: View {
    @ObservedObject var preferences: PreferencesManager

    var body: some View {
        Form {
            Toggle(isOn: $preferences.enabled) {
                Text(settingsLang("Enable Notifications", zh: "启用提醒"))
            }

            Toggle(isOn: $preferences.launchAtLogin) {
                Text(settingsLang("Launch at Login", zh: "开机自启动"))
            }

            Toggle(isOn: $preferences.claudeCodeEnabled) {
                Text(settingsLang("Detect Claude Code state", zh: "检测 Claude Code 状态"))
            }
            Text(settingsLang(
                "Pops on \"needs confirmation\" / \"done\". Writes a hook into ~/.claude/settings.json (backed up; turn off to remove).",
                zh: "在「需要确认 / 对话完成」时弹出。会在 ~/.claude/settings.json 写入 hook（已备份；关闭即移除）。"))
                .font(.caption)
                .foregroundColor(.secondary)

            Picker(selection: $preferences.language) {
                Text(settingsLang("System Default", zh: "跟随系统")).tag("system")
                Text("中文").tag("zh")
                Text("English").tag("en")
            } label: {
                Text(settingsLang("Language", zh: "语言"))
            }

            Picker(selection: $preferences.selectedPet) {
                Text(settingsLang("Pixel Cat", zh: "像素猫")).tag("pixel_cat")
            } label: {
                Text(settingsLang("Pet", zh: "宠物"))
            }
            .disabled(true) // Reserved for future

            HStack {
                Spacer()
                Text(settingsLang("More pets coming soon", zh: "更多宠物即将推出"))
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .padding()
    }
}

// MARK: - Notification Tab

struct NotificationSettingsTab: View {
    @ObservedObject var preferences: PreferencesManager

    @State private var cooldownText: String = ""

    var body: some View {
        Form {
            Toggle(isOn: $preferences.soundEnabled) {
                Text(settingsLang("Play Sound", zh: "播放声音"))
            }

            HStack {
                Text(settingsLang("Cooldown", zh: "冷却时间") + " (\(preferences.cooldownSeconds)s)")
                Slider(value: Binding(
                    get: { Double(preferences.cooldownSeconds) },
                    set: { preferences.cooldownSeconds = Int($0) }
                ), in: 5...120, step: 5)
            }

            Toggle(isOn: $preferences.dndEnabled) {
                Text(settingsLang("Do Not Disturb", zh: "免打扰时段"))
            }

            if preferences.dndEnabled {
                HStack {
                    Text(settingsLang("From", zh: "从"))
                    Picker("", selection: $preferences.dndStartHour) {
                        ForEach(0..<24) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    .frame(width: 80)
                    Text(settingsLang("to", zh: "至"))
                    Picker("", selection: $preferences.dndEndHour) {
                        ForEach(0..<24) { hour in
                            Text(String(format: "%02d:00", hour)).tag(hour)
                        }
                    }
                    .frame(width: 80)
                }
            }

            Toggle(isOn: $preferences.switchToTerminal) {
                Text(settingsLang("Switch to Terminal on dismiss", zh: "关闭提醒后跳转终端"))
            }
        }
        .padding()
    }
}

private func settingsLang(_ en: String, zh: String) -> String {
    let preferred = Locale.preferredLanguages.first ?? "en"
    return preferred.hasPrefix("zh") ? zh : en
}
