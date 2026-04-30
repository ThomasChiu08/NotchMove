//
//  SettingsView.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/17/26.
//

import AppKit
import SwiftUI

enum SettingsPageSection: String, CaseIterable, Identifiable {
    case language
    case startup
    case reminders
    case schedule
    case behavior
    case statistics
    case about

    static let fullSettingsOrder: [SettingsPageSection] = [
        .language,
        .startup,
        .reminders,
        .schedule,
        .behavior,
        .statistics,
        .about,
    ]

    static let dashboardOrder: [SettingsPageSection] = [
        .reminders,
        .schedule,
        .behavior,
        .statistics,
        .language,
        .startup,
        .about,
    ]

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .language: "section.language"
        case .startup: "section.startup"
        case .reminders: "section.reminders"
        case .schedule: "section.schedule"
        case .behavior: "section.behavior"
        case .statistics: "section.statistics"
        case .about: "section.about"
        }
    }

    var systemImage: String {
        switch self {
        case .language: "globe"
        case .startup: "power"
        case .reminders: "bell"
        case .schedule: "clock"
        case .behavior: "slider.horizontal.3"
        case .statistics: "chart.bar"
        case .about: "info.circle"
        }
    }
}

struct SettingsView: View {
    let languageManager: LanguageManager
    let loginItemManager: any LoginItemManaging
    let preferencesStore: PreferencesStore
    let breakStatsStore: BreakStatsStore

    var body: some View {
        SettingsContentView(
            languageManager: languageManager,
            loginItemManager: loginItemManager,
            preferencesStore: preferencesStore,
            breakStatsStore: breakStatsStore,
            sections: SettingsPageSection.fullSettingsOrder,
            showsSectionHeaders: true
        )
        .frame(minWidth: 420, minHeight: 520)
    }
}

struct SettingsContentView: View {
    let languageManager: LanguageManager
    let loginItemManager: any LoginItemManaging
    @Bindable var preferencesStore: PreferencesStore
    @Bindable var breakStatsStore: BreakStatsStore
    let sections: [SettingsPageSection]
    let showsSectionHeaders: Bool

    @State private var showingResetConfirmation = false
    @State private var availableScreens: [ScreenDescriptor] = []
    @State private var loginItemStatus: LoginItemStatus = .notRegistered
    @State private var launchAtLoginErrorMessage: String?

    private let screenProvider = MainScreenProvider()
    private static let intervalOptions = [15, 20, 25, 30, 45, 60]
    private static let dismissOptions = [30, 45, 60, 90, 120]

    init(
        languageManager: LanguageManager,
        loginItemManager: any LoginItemManaging,
        preferencesStore: PreferencesStore,
        breakStatsStore: BreakStatsStore,
        sections: [SettingsPageSection] = SettingsPageSection.fullSettingsOrder,
        showsSectionHeaders: Bool = true
    ) {
        self.languageManager = languageManager
        self.loginItemManager = loginItemManager
        self.preferencesStore = preferencesStore
        self.breakStatsStore = breakStatsStore
        self.sections = sections
        self.showsSectionHeaders = showsSectionHeaders
    }

    var body: some View {
        Form {
            ForEach(sections) { section in
                settingsSection(section)
            }
        }
        .formStyle(.grouped)
        .onAppear {
            breakStatsStore.refresh()
            refreshAvailableScreens()
            refreshLoginItemStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshAvailableScreens()
        }
    }

    @ViewBuilder
    private func settingsSection(_ section: SettingsPageSection) -> some View {
        switch section {
        case .language:
            languageSection
        case .startup:
            startupSection
        case .reminders:
            remindersSection
        case .schedule:
            scheduleSection
        case .behavior:
            behaviorSection
        case .statistics:
            statisticsSection
        case .about:
            aboutSection
        }
    }

    @ViewBuilder
    private func sectionHeader(_ key: String) -> some View {
        if showsSectionHeaders {
            Text(LocalizedStringKey(key))
        }
    }

    // MARK: - Language

    private var languageSection: some View {
        Section {
            Picker(selection: Binding(
                get: { preferencesStore.preferences.appLanguage },
                set: { preferencesStore.preferences.appLanguage = $0 }
            )) {
                ForEach(LanguageManager.supportedLanguages) { lang in
                    Text(lang.displayName).tag(lang.code)
                }
            } label: {
                Text("current_language")
            }
            .pickerStyle(.menu)
        } header: {
            sectionHeader("section.language")
        } footer: {
            Text("language_description")
        }
    }

    // MARK: - Startup

    private var startupSection: some View {
        Section {
            Toggle(isOn: launchAtLoginBinding) {
                Text("launch_at_login")
            }
        } header: {
            sectionHeader("section.startup")
        } footer: {
            startupFooter
        }
    }

    @ViewBuilder
    private var startupFooter: some View {
        if let launchAtLoginErrorMessage {
            Text(launchAtLoginErrorMessage)
                .foregroundStyle(.red)
        } else if loginItemStatus == .requiresApproval {
            Text("launch_at_login_requires_approval")
        } else {
            Text("launch_at_login_footer")
        }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        Section {
            Picker(selection: $preferencesStore.preferences.reminderIntervalMinutes) {
                ForEach(Self.intervalOptions, id: \.self) { minutes in
                    Text(String(format: localizedString("minutes_format"), minutes))
                        .tag(minutes)
                }
            } label: {
                Text("remind_every")
            }

            Toggle(isOn: $preferencesStore.preferences.sitAwareEnabled) {
                Text("sit_aware_mode")
            }
        } header: {
            sectionHeader("section.reminders")
        } footer: {
            if preferencesStore.preferences.sitAwareEnabled {
                Text("sit_aware_footer_on")
            } else {
                Text("sit_aware_footer_off")
            }
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section {
            Toggle(isOn: $preferencesStore.preferences.schedule.isEnabled) {
                Text("work_hours_only")
            }

            if preferencesStore.preferences.schedule.isEnabled {
                DatePicker(selection: startTimeBinding, displayedComponents: .hourAndMinute) {
                    Text("schedule_from")
                }
                DatePicker(selection: endTimeBinding, displayedComponents: .hourAndMinute) {
                    Text("schedule_to")
                }
                Toggle(isOn: $preferencesStore.preferences.schedule.weekdaysOnly) {
                    Text("weekdays_only")
                }
            }
        } header: {
            sectionHeader("section.schedule")
        } footer: {
            if preferencesStore.preferences.schedule.isEnabled && !isValidTimeRange {
                Text("schedule_invalid")
                    .foregroundStyle(.red)
            } else if preferencesStore.preferences.schedule.isEnabled {
                Text("schedule_footer")
            }
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        Section {
            Picker(selection: $preferencesStore.preferences.overlayDisplayMode) {
                Text("display_automatic")
                    .tag(Preferences.OverlayDisplayMode.automatic)

                ForEach(availableScreens, id: \.displayID) { screen in
                    Text(displayName(for: screen))
                        .tag(Preferences.OverlayDisplayMode.display(screen.displayID))
                }

                if let selectedUnavailableDisplayID {
                    Text(String(format: localizedString("display_unavailable_format"), Int(selectedUnavailableDisplayID)))
                        .tag(Preferences.OverlayDisplayMode.display(selectedUnavailableDisplayID))
                }
            } label: {
                Text("overlay_display")
            }
            .pickerStyle(.menu)

            Toggle(isOn: $preferencesStore.preferences.notchExpansionEnabled) {
                Text("expand_notch")
            }
            Toggle(isOn: $preferencesStore.preferences.hoverPreviewEnabled) {
                Text("show_hover_preview")
            }
            Toggle(isOn: $preferencesStore.preferences.soundEnabled) {
                Text("play_sound")
            }

            Toggle(isOn: $preferencesStore.preferences.autoDismissEnabled) {
                Text("auto_dismiss")
            }
            if preferencesStore.preferences.autoDismissEnabled {
                Picker(selection: $preferencesStore.preferences.autoDismissSeconds) {
                    ForEach(Self.dismissOptions, id: \.self) { seconds in
                        Text(String(format: localizedString("seconds_format"), seconds))
                            .tag(seconds)
                    }
                } label: {
                    Text("dismiss_after")
                }
            }
        } header: {
            sectionHeader("section.behavior")
        } footer: {
            Text("behavior_footer")
        }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        Section {
            LabeledContent {
                Text("\(breakStatsStore.todayBreaks)")
            } label: {
                Text("breaks_today")
            }

            LabeledContent {
                Text("\(breakStatsStore.weekBreaks)")
            } label: {
                Text("breaks_this_week")
            }

            HStack {
                Button(role: .destructive) {
                    showingResetConfirmation = true
                } label: {
                    Text("reset_statistics")
                }
                .confirmationDialog(
                    Text("reset_confirm"),
                    isPresented: $showingResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(role: .destructive) { breakStatsStore.reset() } label: {
                        Text("reset_action")
                    }
                    Button(role: .cancel) {} label: {
                        Text("cancel")
                    }
                }

                Spacer()

                Button {
                    restoreDefaults()
                } label: {
                    Text("restore_defaults")
                }
            }
        } header: {
            sectionHeader("section.statistics")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(appVersion)
            } label: {
                Text("version")
            }

            LabeledContent {
                Text(currentLanguageDisplayName)
            } label: {
                Text("current_language")
            }

            Text("app_description")
                .font(.callout)
                .foregroundStyle(.secondary)
        } header: {
            sectionHeader("section.about")
        }
    }

    // MARK: - Helpers

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { preferencesStore.preferences.launchAtLoginEnabled },
            set: { setLaunchAtLoginEnabled($0) }
        )
    }

    private func setLaunchAtLoginEnabled(_ isEnabled: Bool) {
        launchAtLoginErrorMessage = nil

        do {
            try loginItemManager.setEnabled(isEnabled)
            preferencesStore.preferences.launchAtLoginEnabled = isEnabled
            refreshLoginItemStatus()
        } catch {
            refreshLoginItemStatus()
            launchAtLoginErrorMessage = String(
                format: localizedString("launch_at_login_error_format"),
                error.localizedDescription
            )
        }
    }

    private func refreshLoginItemStatus() {
        loginItemStatus = loginItemManager.status
    }

    private func restoreDefaults() {
        preferencesStore.restoreDefaults()
        launchAtLoginErrorMessage = nil

        do {
            try loginItemManager.setEnabled(preferencesStore.preferences.launchAtLoginEnabled)
        } catch {
            launchAtLoginErrorMessage = String(
                format: localizedString("launch_at_login_error_format"),
                error.localizedDescription
            )
        }

        refreshLoginItemStatus()
    }

    /// Resolves a localization key through the LanguageManager bundle for
    /// format-string usage (where `LocalizedStringKey` can't be used directly).
    private func localizedString(_ key: String) -> String {
        languageManager.localizedString(key)
    }

    private func displayName(for screen: ScreenDescriptor) -> String {
        guard screen.isBuiltIn else { return screen.localizedName }
        return String(format: localizedString("display_builtin_format"), screen.localizedName)
    }

    private var selectedUnavailableDisplayID: CGDirectDisplayID? {
        guard case let .display(displayID) = preferencesStore.preferences.overlayDisplayMode,
              !availableScreens.contains(where: { $0.displayID == displayID })
        else {
            return nil
        }

        return displayID
    }

    private func refreshAvailableScreens() {
        availableScreens = screenProvider.availableScreens()
    }

    private var currentLanguageDisplayName: String {
        LanguageManager.supportedLanguages
            .first { $0.code == preferencesStore.preferences.appLanguage }?
            .displayName ?? "English"
    }

    // MARK: - Date Bindings

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: {
                let schedule = preferencesStore.preferences.schedule
                return dateFrom(hour: schedule.startHour, minute: schedule.startMinute)
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                preferencesStore.preferences.schedule.startHour = comps.hour ?? Preferences.defaults.schedule.startHour
                preferencesStore.preferences.schedule.startMinute = comps.minute ?? Preferences.defaults.schedule.startMinute
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: {
                let schedule = preferencesStore.preferences.schedule
                return dateFrom(hour: schedule.endHour, minute: schedule.endMinute)
            },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                preferencesStore.preferences.schedule.endHour = comps.hour ?? Preferences.defaults.schedule.endHour
                preferencesStore.preferences.schedule.endMinute = comps.minute ?? Preferences.defaults.schedule.endMinute
            }
        )
    }

    private func dateFrom(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
    }

    private var isValidTimeRange: Bool {
        preferencesStore.preferences.schedule.hasValidTimeRange
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    let settings = AppSettings()
    let preferencesStore = PreferencesStore(settings: settings)
    let breakStatsStore = BreakStatsStore(defaults: settings.defaults)
    let languageManager = LanguageManager(preferencesStore: preferencesStore)

    SettingsView(
        languageManager: languageManager,
        loginItemManager: LoginItemService(),
        preferencesStore: preferencesStore,
        breakStatsStore: breakStatsStore
    )
        .frame(width: 420, height: 600)
}
