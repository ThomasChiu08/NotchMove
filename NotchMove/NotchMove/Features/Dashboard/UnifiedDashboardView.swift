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
    @Bindable var scheduleStore: DailyScheduleStore
    @Bindable var preferencesStore: PreferencesStore
    @Bindable var breakStatsStore: BreakStatsStore

    @AppStorage("unifiedDashboardSelectedPage") private var selectedPageID = UnifiedDashboardPage.dailySchedule.id

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
        List(selection: $selectedPageID) {
            Section("dashboard.sidebar.workspace") {
                Label {
                    Text("dashboard.title")
                } icon: {
                    Image(systemName: "calendar")
                }
                .tag(UnifiedDashboardPage.dailySchedule.id)
            }

            Section("dashboard.sidebar.settings") {
                ForEach(SettingsPageSection.dashboardOrder) { section in
                    Label {
                        Text(LocalizedStringKey(section.titleKey))
                    } icon: {
                        Image(systemName: section.systemImage)
                    }
                    .tag(UnifiedDashboardPage.settings(section).id)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle(Text("dashboard.unified.title"))
    }

    @ViewBuilder
    private var detail: some View {
        switch selectedPage {
        case .dailySchedule:
            DailyScheduleDashboardView(
                languageManager: languageManager,
                scheduleStore: scheduleStore
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
        UnifiedDashboardPage(id: selectedPageID) ?? .dailySchedule
    }

    private func normalizeSelection() {
        guard UnifiedDashboardPage(id: selectedPageID) == nil else { return }
        selectedPageID = UnifiedDashboardPage.dailySchedule.id
    }
}

enum UnifiedDashboardPage: Hashable, Identifiable {
    case dailySchedule
    case settings(SettingsPageSection)

    var id: String {
        switch self {
        case .dailySchedule:
            "dailySchedule"
        case .settings(let section):
            "settings.\(section.rawValue)"
        }
    }

    init?(id: String) {
        if id == Self.dailySchedule.id {
            self = .dailySchedule
            return
        }

        guard id.hasPrefix("settings.") else { return nil }
        let rawSection = String(id.dropFirst("settings.".count))
        guard let section = SettingsPageSection(rawValue: rawSection) else { return nil }
        self = .settings(section)
    }
}

struct DashboardPageHeader<Actions: View>: View {
    let titleKey: String
    let systemImage: String?
    let actions: Actions

    init(
        titleKey: String,
        systemImage: String? = nil,
        @ViewBuilder actions: () -> Actions
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.actions = actions()
    }

    var body: some View {
        HStack(spacing: 12) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)
            }

            Text(LocalizedStringKey(titleKey))
                .font(.title2.weight(.semibold))
                .lineLimit(1)

            Spacer(minLength: 16)

            actions
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

extension DashboardPageHeader where Actions == EmptyView {
    init(titleKey: String, systemImage: String? = nil) {
        self.init(titleKey: titleKey, systemImage: systemImage) {
            EmptyView()
        }
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
        scheduleStore: DailyScheduleStore(defaults: settings.defaults),
        preferencesStore: preferencesStore,
        breakStatsStore: breakStatsStore
    )
    .frame(width: 920, height: 640)
}
