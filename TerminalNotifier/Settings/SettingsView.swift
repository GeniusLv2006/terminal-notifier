import SwiftUI

struct SettingsView: View {
    @ObservedObject var preferences: PreferencesManager
    @AppStorage("language") private var language: String = "system"
    @State private var selectedSection: SettingsSection = .general

    private var locale: String { PreferencesManager.resolveLocale(language) }

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(
                selection: $selectedSection,
                locale: locale,
                isEnabled: preferences.enabled,
                claudeEnabled: preferences.claudeCodeEnabled,
                codexEnabled: preferences.codexAppEnabled
            )
            Divider()
            ScrollView {
                detailView
                    .padding(.horizontal, 30)
                    .padding(.vertical, 26)
            }
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 740, height: 500)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var detailView: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsPane(preferences: preferences, locale: locale)
        case .notifications:
            NotificationSettingsPane(preferences: preferences, locale: locale)
        case .appearance:
            AppearanceSettingsPane(preferences: preferences, locale: locale)
        }
    }
}

private enum SettingsSection: String, CaseIterable, Identifiable {
    case general
    case notifications
    case appearance

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .general: return "switch.2"
        case .notifications: return "bell.badge"
        case .appearance: return "paintpalette"
        }
    }

    func title(locale: String) -> String {
        switch self {
        case .general:
            return settingsLang("General", zh: "通用", locale: locale)
        case .notifications:
            return settingsLang("Notifications", zh: "通知", locale: locale)
        case .appearance:
            return settingsLang("Appearance", zh: "外观", locale: locale)
        }
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsSection
    let locale: String
    let isEnabled: Bool
    let claudeEnabled: Bool
    let codexEnabled: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: 8) {
                Image(nsImage: StatusBarController.createColoredCatIcon(size: 38))
                    .interpolation(.none)
                    .frame(width: 38, height: 38)

                Text("Terminal Notifier")
                    .font(.system(size: 18, weight: .semibold))

                HStack(spacing: 6) {
                    Circle()
                        .fill(isEnabled ? Color.green : Color.secondary.opacity(0.45))
                        .frame(width: 8, height: 8)
                    Text(isEnabled
                         ? settingsLang("Notifications active", zh: "提醒已启用", locale: locale)
                         : settingsLang("Notifications paused", zh: "提醒已暂停", locale: locale))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .font(.caption)

                Text(claudeEnabled
                     ? settingsLang("Claude Code detection is on", zh: "Claude Code 检测已开启", locale: locale)
                     : settingsLang("Claude Code detection is off", zh: "Claude Code 检测未开启", locale: locale))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                Text(codexEnabled
                     ? settingsLang("Codex detection is on", zh: "Codex 检测已开启", locale: locale)
                     : settingsLang("Codex detection is off", zh: "Codex 检测未开启", locale: locale))
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            .padding(.top, 26)
            .padding(.horizontal, 18)

            VStack(spacing: 6) {
                ForEach(SettingsSection.allCases) { section in
                    SettingsSidebarButton(
                        title: section.title(locale: locale),
                        systemImage: section.systemImage,
                        isSelected: selection == section
                    ) {
                        selection = section
                    }
                }
            }
            .padding(.horizontal, 12)

            Spacer()

            Text(settingsLang("Compatible with macOS 13 and later", zh: "兼容 macOS 13 及更新版本", locale: locale))
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.horizontal, 18)
                .padding(.bottom, 18)
        }
        .frame(width: 218)
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.72))
    }
}

private struct SettingsSidebarButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .imageScale(.medium)
                }
                .frame(width: 24, height: 20, alignment: .center)
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundColor(isSelected ? .primary : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.16) : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .buttonStyle(.plain)
    }
}

private struct GeneralSettingsPane: View {
    @ObservedObject var preferences: PreferencesManager
    let locale: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHeader(
                title: settingsLang("General", zh: "通用", locale: locale),
                subtitle: settingsLang("Control how Terminal Notifier starts and what it watches.", zh: "管理启动方式和需要监听的状态。", locale: locale)
            )

            SettingsCard(
                title: settingsLang("Notification State", zh: "提醒状态", locale: locale),
                systemImage: "power",
                subtitle: settingsLang("Pause all visual and sound reminders without quitting the app.", zh: "无需退出应用即可暂停所有视觉和声音提醒。", locale: locale)
            ) {
                SettingsToggleRow(
                    title: settingsLang("Enable notifications", zh: "启用提醒", locale: locale),
                    subtitle: settingsLang("When off, Terminal Notifier stays in the menu bar but does not show reminders.", zh: "关闭后应用仍保留在菜单栏，但不会弹出提醒。", locale: locale),
                    isOn: $preferences.enabled
                )
            }

            SettingsCard(
                title: settingsLang("Startup", zh: "启动", locale: locale),
                systemImage: "arrow.clockwise.circle",
                subtitle: nil
            ) {
                SettingsToggleRow(
                    title: settingsLang("Launch at login", zh: "开机自启动", locale: locale),
                    subtitle: settingsLang("Start Terminal Notifier automatically after you sign in.", zh: "登录系统后自动启动 Terminal Notifier。", locale: locale),
                    isOn: $preferences.launchAtLogin
                )
            }

            SettingsCard(
                title: "Claude Code",
                systemImage: "terminal",
                subtitle: settingsLang("Optional hook-based integration for confirmation and completion moments.", zh: "可选的 hook 集成，用于捕捉需要确认和完成对话的时刻。", locale: locale)
            ) {
                SettingsToggleRow(
                    title: settingsLang("Detect Claude Code state", zh: "检测 Claude Code 状态", locale: locale),
                    subtitle: settingsLang("Writes a managed hook into ~/.claude/settings.json. A backup is kept and disabling removes the hook.", zh: "会向 ~/.claude/settings.json 写入受管理的 hook。已备份，关闭后会移除。", locale: locale),
                    isOn: $preferences.claudeCodeEnabled
                )
            }

            SettingsCard(
                title: "Codex",
                systemImage: "macwindow",
                subtitle: settingsLang("Optional Codex hook integration for approval and turn-completion moments.", zh: "可选的 Codex hook 集成，用于捕捉需要确认和完成对话的时刻。", locale: locale)
            ) {
                SettingsToggleRow(
                    title: settingsLang("Detect Codex state", zh: "检测 Codex 状态", locale: locale),
                    subtitle: settingsLang("Writes managed hooks into ~/.codex/hooks.json.", zh: "会向 ~/.codex/hooks.json 写入受管理的 hooks。", locale: locale),
                    isOn: $preferences.codexAppEnabled
                )

                SettingsDivider()

                SettingsWarningNote(
                    title: settingsLang("Trust required in Codex", zh: "必须在 Codex 中信任 hooks", locale: locale),
                    message: settingsLang(
                        "After enabling this, restart or reopen Codex, then review and trust both PermissionRequest and Stop in Codex Settings > Hooks. Reminders will not fire until those hooks are trusted.",
                        zh: "开启后请重启或重新打开 Codex，然后在 Codex 设置 > 钩子中审核并信任 PermissionRequest 和 Stop。未信任前不会触发提醒。",
                        locale: locale)
                )

                SettingsDivider()

                SettingsWarningNote(
                    title: settingsLang("Known issue: auto-review", zh: "已知问题：auto-review", locale: locale),
                    message: settingsLang(
                        "Codex auto-review can still emit PermissionRequest hooks, so a confirmation reminder may appear even when Codex handles the review automatically.",
                        zh: "Codex auto-review 仍可能触发 PermissionRequest hook，因此即使 Codex 自动完成审核，也可能出现需要确认提醒。",
                        locale: locale)
                )
            }
        }
    }
}

private struct NotificationSettingsPane: View {
    @ObservedObject var preferences: PreferencesManager
    let locale: String
    private let cooldownOptions = [5, 10, 15, 30, 60, 120]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHeader(
                title: settingsLang("Notifications", zh: "通知", locale: locale),
                subtitle: settingsLang("Tune sound, cooldown, quiet hours, and dismiss behavior.", zh: "调整声音、冷却时间、免打扰时段和关闭提醒后的行为。", locale: locale)
            )

            SettingsCard(
                title: settingsLang("Feedback", zh: "反馈", locale: locale),
                systemImage: "speaker.wave.2",
                subtitle: nil
            ) {
                SettingsToggleRow(
                    title: settingsLang("Play sound", zh: "播放声音", locale: locale),
                    subtitle: settingsLang("Use the system alert sound when a reminder appears.", zh: "提醒出现时播放系统提示音。", locale: locale),
                    isOn: $preferences.soundEnabled
                )

                SettingsDivider()

                SettingsControlRow(
                    title: settingsLang("Cooldown", zh: "冷却时间", locale: locale),
                    subtitle: settingsLang("Minimum time between repeated reminders.", zh: "重复提醒之间的最短间隔。", locale: locale)
                ) {
                    Picker("", selection: $preferences.cooldownSeconds) {
                        ForEach(cooldownOptions, id: \.self) { sec in
                            Text(settingsLang("\(sec)s", zh: "\(sec) 秒", locale: locale)).tag(sec)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 104)
                }
            }

            SettingsCard(
                title: settingsLang("Quiet Hours", zh: "免打扰", locale: locale),
                systemImage: "moon",
                subtitle: settingsLang("Suppress reminders during your chosen time window.", zh: "在指定时段内静默提醒。", locale: locale)
            ) {
                SettingsToggleRow(
                    title: settingsLang("Do Not Disturb", zh: "免打扰时段", locale: locale),
                    subtitle: settingsLang("Applies to Terminal, Claude Code, and Codex reminders.", zh: "同时作用于终端、Claude Code 和 Codex 提醒。", locale: locale),
                    isOn: $preferences.dndEnabled
                )

                if preferences.dndEnabled {
                    SettingsDivider()
                    SettingsControlRow(
                        title: settingsLang("Schedule", zh: "时段", locale: locale),
                        subtitle: settingsLang("Cross-midnight ranges are supported.", zh: "支持跨午夜时段。", locale: locale)
                    ) {
                        HStack(spacing: 8) {
                            HourPicker(selection: $preferences.dndStartHour)
                            Text(settingsLang("to", zh: "至", locale: locale))
                                .foregroundColor(.secondary)
                            HourPicker(selection: $preferences.dndEndHour)
                        }
                    }
                }
            }

            SettingsCard(
                title: settingsLang("Dismiss Action", zh: "关闭动作", locale: locale),
                systemImage: "arrowshape.turn.up.right",
                subtitle: nil
            ) {
                SettingsToggleRow(
                    title: settingsLang("Switch to source app on dismiss", zh: "关闭提醒后跳转来源应用", locale: locale),
                    subtitle: settingsLang("Bring Terminal or Codex forward after you dismiss a reminder.", zh: "关闭提醒后将 Terminal 或 Codex 带到前台。", locale: locale),
                    isOn: $preferences.switchToTerminal
                )
            }
        }
    }
}

private struct AppearanceSettingsPane: View {
    @ObservedObject var preferences: PreferencesManager
    let locale: String

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            SettingsHeader(
                title: settingsLang("Appearance", zh: "外观", locale: locale),
                subtitle: settingsLang("Keep the app native while preserving the pixel-cat identity.", zh: "保持原生系统感，同时保留像素猫识别。", locale: locale)
            )

            SettingsCard(
                title: settingsLang("Language", zh: "语言", locale: locale),
                systemImage: "globe",
                subtitle: nil
            ) {
                SettingsControlRow(
                    title: settingsLang("Interface language", zh: "界面语言", locale: locale),
                    subtitle: settingsLang("Used by settings and reminder messages.", zh: "用于设置界面和提醒文案。", locale: locale)
                ) {
                    Picker("", selection: $preferences.language) {
                        Text(settingsLang("System", zh: "跟随系统", locale: locale)).tag("system")
                        Text("中文").tag("zh")
                        Text("English").tag("en")
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .frame(width: 216)
                }
            }

            SettingsCard(
                title: settingsLang("Pet", zh: "宠物", locale: locale),
                systemImage: "sparkle",
                subtitle: settingsLang("The current release ships with one carefully tuned pixel companion.", zh: "当前版本内置一个经过调校的像素伙伴。", locale: locale)
            ) {
                SettingsControlRow(
                    title: settingsLang("Companion", zh: "伙伴", locale: locale),
                    subtitle: settingsLang("More pets are planned for a future release.", zh: "更多宠物将在后续版本推出。", locale: locale)
                ) {
                    Picker("", selection: $preferences.selectedPet) {
                        Text(settingsLang("Orange Cat", zh: "橘猫", locale: locale)).tag("pixel_cat")
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 130)
                    .disabled(true)
                }
            }
        }
    }
}

private struct SettingsHeader: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 26, weight: .semibold))
            Text(subtitle)
                .font(.system(size: 13))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, 2)
    }
}

private struct SettingsCard<Content: View>: View {
    let title: String
    let systemImage: String
    let subtitle: String?
    let content: Content

    init(title: String, systemImage: String, subtitle: String?, @ViewBuilder content: () -> Content) {
        self.title = title
        self.systemImage = systemImage
        self.subtitle = subtitle
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 10) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.accentColor.opacity(0.12))
                    Image(systemName: systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .imageScale(.medium)
                        .foregroundColor(.accentColor)
                }
                .frame(width: 28, height: 28, alignment: .center)

                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 14, weight: .semibold))
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer()
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color(nsColor: .separatorColor).opacity(0.45), lineWidth: 1)
        )
    }
}

private struct SettingsToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        SettingsControlRow(title: title, subtitle: subtitle) {
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
                .labelsHidden()
        }
    }
}

private struct SettingsControlRow<Control: View>: View {
    let title: String
    let subtitle: String
    let control: Control

    init(title: String, subtitle: String, @ViewBuilder control: () -> Control) {
        self.title = title
        self.subtitle = subtitle
        self.control = control()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 18) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 20)
            control
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct SettingsDivider: View {
    var body: some View {
        Rectangle()
            .fill(Color(nsColor: .separatorColor).opacity(0.42))
            .frame(height: 1)
    }
}

private struct SettingsWarningNote: View {
    let title: String
    let message: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)
                .frame(width: 18, height: 18)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.orange.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
    }
}

private struct HourPicker: View {
    @Binding var selection: Int

    var body: some View {
        Picker("", selection: $selection) {
            ForEach(0..<24) { hour in
                Text(String(format: "%02d:00", hour)).tag(hour)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .frame(width: 82)
    }
}

private func settingsLang(_ en: String, zh: String, locale: String) -> String {
    locale == "zh" ? zh : en
}
