//
//  UnifiedDashboardView.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import SwiftUI

struct UnifiedDashboardView: View {
    let languageManager: LanguageManager
    let loginItemManager: any LoginItemManaging
    let reminderEngine: ReminderEngine
    @Bindable var scheduleStore: DailyScheduleStore
    @Bindable var preferencesStore: PreferencesStore
    @Bindable var breakStatsStore: BreakStatsStore

    @AppStorage("unifiedDashboardSelectedPage") private var selectedPageID = UnifiedDashboardPage.today.id

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 860, minHeight: 560)
        .onAppear(perform: normalizeSelection)
        .onChange(of: selectedPageID) { _, _ in
            normalizeSelection()
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            sidebarStatus

            Divider()

            List(selection: $selectedPageID) {
                Section("dashboard.sidebar.workspace") {
                    ForEach(UnifiedDashboardPage.workspacePages) { page in
                        Label {
                            Text(LocalizedStringKey(page.titleKey))
                        } icon: {
                            Image(systemName: page.systemImage)
                                .foregroundStyle(.secondary)
                        }
                        .tag(page.id)
                    }
                }

                Section("dashboard.sidebar.settings") {
                    ForEach(SettingsPageSection.dashboardOrder) { section in
                        Label {
                            Text(LocalizedStringKey(section.titleKey))
                        } icon: {
                            Image(systemName: section.systemImage)
                                .foregroundStyle(.secondary)
                        }
                        .tag(UnifiedDashboardPage.settings(section).id)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .navigationTitle(Text("dashboard.unified.title"))
    }

    private var sidebarStatus: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("NotchMove")
                .font(.headline)
                .lineLimit(1)

            HStack(spacing: 6) {
                Circle()
                    .fill(sidebarStatusColor)
                    .frame(width: 6, height: 6)

                Text(LocalizedStringKey(sidebarStatusKey))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 18)
        .padding(.bottom, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var sidebarStatusKey: String {
        switch reminderEngine.runState {
        case .tracking:
            "dashboard.run_state.tracking"
        case .manuallyPaused:
            "dashboard.run_state.paused"
        case .scheduleBlocked:
            "dashboard.run_state.schedule_blocked"
        case .presentingReminder:
            "dashboard.run_state.reminding"
        case .idleSuppressed:
            "dashboard.run_state.idle"
        }
    }

    private var sidebarStatusColor: Color {
        switch reminderEngine.runState {
        case .tracking, .presentingReminder:
            .green
        case .manuallyPaused, .scheduleBlocked, .idleSuppressed:
            .secondary
        }
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedPage {
        case .today:
            TodayDashboardView(
                languageManager: languageManager,
                scheduleStore: scheduleStore,
                preferencesStore: preferencesStore,
                breakStatsStore: breakStatsStore,
                reminderEngine: reminderEngine
            )
        case .schedule:
            DailyScheduleDashboardView(
                languageManager: languageManager,
                scheduleStore: scheduleStore
            )
        case .breaks:
            BreaksDashboardView(
                languageManager: languageManager,
                breakStatsStore: breakStatsStore
            )
        case .settings(let section):
            DashboardSettingsPage(
                section: section,
                languageManager: languageManager,
                loginItemManager: loginItemManager,
                preferencesStore: preferencesStore,
                breakStatsStore: breakStatsStore
            )
        }
    }

    private var selectedPage: UnifiedDashboardPage {
        UnifiedDashboardPage(id: selectedPageID) ?? .today
    }

    private func normalizeSelection() {
        guard UnifiedDashboardPage(id: selectedPageID) == nil else { return }
        selectedPageID = UnifiedDashboardPage.today.id
    }
}

enum UnifiedDashboardPage: Hashable, Identifiable {
    case today
    case schedule
    case breaks
    case settings(SettingsPageSection)

    static let workspacePages: [UnifiedDashboardPage] = [.today, .schedule, .breaks]

    var id: String {
        switch self {
        case .today:
            "today"
        case .schedule:
            "schedule"
        case .breaks:
            "breaks"
        case .settings(let section):
            "settings.\(section.rawValue)"
        }
    }

    var titleKey: String {
        switch self {
        case .today:
            "dashboard.page.today"
        case .schedule:
            "dashboard.page.schedule"
        case .breaks:
            "dashboard.page.breaks"
        case .settings(let section):
            section.titleKey
        }
    }

    var systemImage: String {
        switch self {
        case .today:
            "sun.max"
        case .schedule:
            "calendar"
        case .breaks:
            "figure.stand"
        case .settings(let section):
            section.systemImage
        }
    }

    init?(id: String) {
        if let workspacePage = Self.workspacePages.first(where: { $0.id == id }) {
            self = workspacePage
            return
        }

        guard id.hasPrefix("settings.") else { return nil }
        let rawSection = String(id.dropFirst("settings.".count))
        guard let section = SettingsPageSection(rawValue: rawSection),
              SettingsPageSection.dashboardOrder.contains(section)
        else {
            return nil
        }
        self = .settings(section)
    }
}

struct DashboardPageHeader<Actions: View>: View {
    let titleKey: String
    let systemImage: String?
    let metaText: String?
    let actions: Actions

    init(
        titleKey: String,
        systemImage: String? = nil,
        metaText: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.metaText = metaText
        self.actions = actions()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 10) {
                    if let systemImage {
                        Image(systemName: systemImage)
                            .font(.title3)
                            .foregroundStyle(.secondary)
                            .frame(width: 22)
                    }

                    Text(LocalizedStringKey(titleKey))
                        .font(.system(size: 28, weight: .semibold))
                        .lineLimit(1)
                }

                if let metaText {
                    Text(metaText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Spacer(minLength: 16)

            actions
                .controlSize(.small)
        }
        .padding(.horizontal, 24)
        .padding(.top, 22)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension DashboardPageHeader where Actions == EmptyView {
    init(titleKey: String, systemImage: String? = nil, metaText: String? = nil) {
        self.init(titleKey: titleKey, systemImage: systemImage, metaText: metaText) {
            EmptyView()
        }
    }
}

struct DashboardDocumentPage<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                content
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .frame(maxWidth: 860, alignment: .leading)
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
}

struct DashboardSectionBlock<Content: View>: View {
    let titleKey: String
    let content: Content

    init(_ titleKey: String, @ViewBuilder content: () -> Content) {
        self.titleKey = titleKey
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStringKey(titleKey))
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)

            VStack(spacing: 0) {
                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

struct DashboardPropertyRow<Content: View>: View {
    let titleKey: String
    let captionKey: String?
    let content: Content

    init(
        _ titleKey: String,
        captionKey: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.titleKey = titleKey
        self.captionKey = captionKey
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .center, spacing: 18) {
                Text(LocalizedStringKey(titleKey))
                    .foregroundStyle(.secondary)
                    .frame(width: 170, alignment: .leading)

                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let captionKey {
                Text(LocalizedStringKey(captionKey))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 188)
            }
        }
        .font(.system(size: 13))
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
        }
    }
}

struct DashboardValueRow: View {
    let titleKey: String
    let value: String
    let secondaryValue: String?

    init(_ titleKey: String, value: String, secondaryValue: String? = nil) {
        self.titleKey = titleKey
        self.value = value
        self.secondaryValue = secondaryValue
    }

    var body: some View {
        DashboardPropertyRow(titleKey) {
            HStack(spacing: 8) {
                Text(value)
                    .foregroundStyle(.primary)

                if let secondaryValue {
                    Text(secondaryValue)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

struct DashboardEmptyInline<Actions: View>: View {
    let descriptionKey: String
    let actions: Actions

    init(
        descriptionKey: String,
        @ViewBuilder actions: () -> Actions
    ) {
        self.descriptionKey = descriptionKey
        self.actions = actions()
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(LocalizedStringKey(descriptionKey))
                .foregroundStyle(.secondary)

            actions
                .controlSize(.small)
        }
        .font(.system(size: 13))
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct DashboardSettingsPage: View {
    let section: SettingsPageSection
    let languageManager: LanguageManager
    let loginItemManager: any LoginItemManaging
    let preferencesStore: PreferencesStore
    let breakStatsStore: BreakStatsStore

    var body: some View {
        VStack(spacing: 0) {
            DashboardPageHeader(titleKey: section.titleKey, systemImage: section.systemImage)

            Divider()

            SettingsContentView(
                languageManager: languageManager,
                loginItemManager: loginItemManager,
                preferencesStore: preferencesStore,
                breakStatsStore: breakStatsStore,
                sections: [section],
                showsSectionHeaders: false
            )
            .id(section.id)
        }
    }
}

#Preview {
    let settings = AppSettings()
    let preferencesStore = PreferencesStore(settings: settings)
    let breakStatsStore = BreakStatsStore(defaults: settings.defaults)
    let languageManager = LanguageManager(preferencesStore: preferencesStore)

    UnifiedDashboardView(
        languageManager: languageManager,
        loginItemManager: LoginItemService(),
        reminderEngine: ReminderEngine(
            activityMonitor: PreviewDashboardIdleProvider(),
            preferencesStore: preferencesStore,
            soundPlayer: PreviewDashboardSoundPlayer(),
            breakStatsStore: breakStatsStore
        ),
        scheduleStore: DailyScheduleStore(defaults: settings.defaults),
        preferencesStore: preferencesStore,
        breakStatsStore: breakStatsStore
    )
    .frame(width: 920, height: 640)
}

@MainActor
private final class PreviewDashboardIdleProvider: IdleTimeProviding {
    var idleSeconds: TimeInterval = 0
}

@MainActor
private struct PreviewDashboardSoundPlayer: SoundPlaying {
    func playReminderSound() {}
}
