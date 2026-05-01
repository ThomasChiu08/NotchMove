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
    case aiAssistant
    case schedule
    case behavior
    case statistics
    case about

    static let fullSettingsOrder: [SettingsPageSection] = [
        .language,
        .startup,
        .reminders,
        .aiAssistant,
        .behavior,
        .statistics,
        .about,
    ]

    static let dashboardOrder: [SettingsPageSection] = [
        .reminders,
        .aiAssistant,
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
        case .aiAssistant: "section.ai_assistant"
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
        case .aiAssistant: "mic"
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
    let aiProviderPreferences: AIProviderPreferences
    let breakStatsStore: BreakStatsStore

    var body: some View {
        SettingsContentView(
            languageManager: languageManager,
            loginItemManager: loginItemManager,
            preferencesStore: preferencesStore,
            aiProviderPreferences: aiProviderPreferences,
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
    @Bindable var aiProviderPreferences: AIProviderPreferences
    @Bindable var breakStatsStore: BreakStatsStore
    let sections: [SettingsPageSection]
    let showsSectionHeaders: Bool

    @State private var showingResetConfirmation = false
    @State private var showingRestoreConfirmation = false
    @State private var availableScreens: [ScreenDescriptor] = []
    @State private var loginItemStatus: LoginItemStatus = .notRegistered
    @State private var launchAtLoginErrorMessage: String?
    @State private var credentials: [String: String] = [:]
    @State private var apiKeyStatusMessage: String?
    @State private var isTestingTranscriptionProvider = false
    @State private var isTestingParserProvider = false
    @State private var setupGuideProvider: AIProviderID?
    @State private var localSpeechModelStore: LocalSpeechModelStore

    private let screenProvider = MainScreenProvider()
    private static let intervalOptions = [15, 20, 25, 30, 45, 60]
    private static let dismissOptions = [30, 45, 60, 90, 120]

    init(
        languageManager: LanguageManager,
        loginItemManager: any LoginItemManaging,
        preferencesStore: PreferencesStore,
        aiProviderPreferences: AIProviderPreferences,
        breakStatsStore: BreakStatsStore,
        sections: [SettingsPageSection] = SettingsPageSection.fullSettingsOrder,
        showsSectionHeaders: Bool = true
    ) {
        self.languageManager = languageManager
        self.loginItemManager = loginItemManager
        self.preferencesStore = preferencesStore
        self.aiProviderPreferences = aiProviderPreferences
        self.breakStatsStore = breakStatsStore
        self.sections = sections
        self.showsSectionHeaders = showsSectionHeaders
        self._localSpeechModelStore = State(initialValue: LocalSpeechModelStore(defaults: aiProviderPreferences.defaults))
    }

    var body: some View {
        Form {
            ForEach(sections) { section in
                settingsSection(section)
            }
        }
        .formStyle(.grouped)
        .controlSize(.small)
        .onAppear {
            breakStatsStore.refresh()
            refreshAvailableScreens()
            refreshLoginItemStatus()
            loadAPIKeys()
            refreshLocalModelState()
        }
        .onChange(of: aiProviderPreferences.transcriptionProviderID) {
            refreshLocalModelState()
        }
        .onChange(of: aiProviderPreferences.transcriptionModel) {
            refreshLocalModelState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didChangeScreenParametersNotification)) { _ in
            refreshAvailableScreens()
        }
        .sheet(item: $setupGuideProvider) { provider in
            AIProviderSetupGuideSheet(
                provider: provider,
                guide: provider.definition.setupGuide,
                languageManager: languageManager
            )
            .environment(\.locale, languageManager.locale)
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
        case .aiAssistant:
            aiAssistantSection
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
            SettingsPropertyRow("current_language", captionKey: "language_description") {
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
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 220, alignment: .leading)
            }
        } header: {
            sectionHeader("section.language")
        }
    }

    // MARK: - Startup

    private var startupSection: some View {
        Section {
            SettingsPropertyRow("launch_at_login") {
                Toggle(isOn: launchAtLoginBinding) {
                    Text("launch_at_login")
                }
                .labelsHidden()
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
            SettingsPropertyRow("remind_every", captionKey: sitAwareCaptionKey) {
                Picker(selection: $preferencesStore.preferences.reminderIntervalMinutes) {
                    ForEach(Self.intervalOptions, id: \.self) { minutes in
                        Text(String(format: localizedString("minutes_format"), minutes))
                            .tag(minutes)
                    }
                } label: {
                    Text("remind_every")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 140, alignment: .leading)
            }

            SettingsPropertyRow("sit_aware_mode") {
                Toggle(isOn: $preferencesStore.preferences.sitAwareEnabled) {
                    Text("sit_aware_mode")
                }
                .labelsHidden()
            }
        } header: {
            sectionHeader("section.reminders")
        }
    }

    // MARK: - AI Assistant

    private var aiAssistantSection: some View {
        Section {
            SettingsPropertyRow("ai.settings.enabled") {
                Toggle(isOn: $aiProviderPreferences.isEnabled) {
                    Text("ai.settings.enabled")
                }
                .labelsHidden()
            }

            SettingsPropertyRow("ai.settings.transcription_provider") {
                Picker(selection: transcriptionProviderBinding) {
                    ForEach(AIProviderPreferences.supportedTranscriptionProviders) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                } label: {
                    Text("ai.settings.transcription_provider")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 180, alignment: .leading)
            }

            SettingsPropertyRow("ai.settings.transcription_model") {
                if aiProviderPreferences.availableTranscriptionModels.isEmpty {
                    TextField("ai.settings.transcription_model", text: $aiProviderPreferences.transcriptionModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 220, alignment: .leading)
                } else {
                    Picker(selection: $aiProviderPreferences.transcriptionModel) {
                        ForEach(aiProviderPreferences.availableTranscriptionModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    } label: {
                        Text("ai.settings.transcription_model")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 220, alignment: .leading)
                }
            }

            if aiProviderPreferences.selectedTranscriptionProvider == .localWhisperKit {
                localModelControls
            }

            SettingsPropertyRow("ai.settings.parser_provider") {
                Picker(selection: parserProviderBinding) {
                    ForEach(AIProviderPreferences.supportedParserProviders) { provider in
                        Text(provider.displayName).tag(provider.rawValue)
                    }
                } label: {
                    Text("ai.settings.parser_provider")
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(maxWidth: 180, alignment: .leading)
            }

            SettingsPropertyRow("ai.settings.parser_model") {
                if aiProviderPreferences.availableParserModels.isEmpty {
                    TextField("ai.settings.parser_model", text: $aiProviderPreferences.parserModel)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260, alignment: .leading)
                } else {
                    Picker(selection: $aiProviderPreferences.parserModel) {
                        ForEach(aiProviderPreferences.availableParserModels, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    } label: {
                        Text("ai.settings.parser_model")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 220, alignment: .leading)
                }
            }

            if aiProviderPreferences.selectedParserProvider == .customOpenAICompatible {
                SettingsPropertyRow("ai.settings.custom_base_url") {
                    TextField("https://example.com/v1", text: $aiProviderPreferences.customParserBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 320, alignment: .leading)
                }
            }

            SettingsPropertyRow("ai.settings.default_lead") {
                Stepper(value: $aiProviderPreferences.defaultReminderLeadMinutes, in: 0...120, step: 5) {
                    Text(String(
                        format: localizedString("dashboard.field.lead_minutes_format"),
                        aiProviderPreferences.defaultReminderLeadMinutes
                    ))
                }
            }

            ForEach(aiProviderPreferences.credentialRequestsForCurrentFlow) { request in
                credentialRow(for: request)
            }

            SettingsPropertyRow("ai.settings.test_transcription") {
                HStack(spacing: 8) {
                    Button("ai.settings.test_transcription") {
                        testTranscriptionProvider()
                    }
                    .disabled(isTestingTranscriptionProvider)

                    if isTestingTranscriptionProvider {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }

            SettingsPropertyRow("ai.settings.test_parser") {
                HStack(spacing: 8) {
                    Button("ai.settings.test_parser") {
                        testParserProvider()
                    }
                    .disabled(isTestingParserProvider)

                    if isTestingParserProvider {
                        ProgressView()
                            .controlSize(.small)
                    }
                }
            }

            if let apiKeyStatusMessage {
                Text(apiKeyStatusMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        } header: {
            sectionHeader("section.ai_assistant")
        } footer: {
            Text(LocalizedStringKey(aiSettingsPrivacyFooterKey))
        }
    }

    private var localModelControls: some View {
        SettingsPropertyRow("ai.settings.local_model") {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    Text(localModelStatusText)
                        .foregroundStyle(localModelStatusColor)

                    if isLocalModelBusy {
                        ProgressView()
                            .controlSize(.small)
                    }

                    Button("ai.settings.local_model_download") {
                        downloadLocalModel()
                    }
                    .disabled(isLocalModelBusy || selectedLocalSpeechModel == nil)

                    Button("ai.settings.local_model_verify") {
                        verifyLocalModel()
                    }
                    .disabled(isLocalModelBusy || selectedLocalSpeechModel == nil)

                    Button(role: .destructive) {
                        deleteLocalModel()
                    } label: {
                        Text("ai.settings.local_model_delete")
                    }
                    .disabled(!canDeleteLocalModel)
                }

                if let selectedLocalSpeechModel {
                    Text(String(
                        format: localizedString("ai.settings.local_model_disk_usage_format"),
                        selectedLocalSpeechModel.approximateDiskUsage
                    ))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                }
            }
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section {
            workHoursRows
        } header: {
            sectionHeader("section.schedule")
        } footer: {
            scheduleFooter
        }
    }

    @ViewBuilder
    private var workHoursRows: some View {
        SettingsPropertyRow("work_hours_only") {
            Toggle(isOn: $preferencesStore.preferences.schedule.isEnabled) {
                Text("work_hours_only")
            }
            .labelsHidden()
        }

        if preferencesStore.preferences.schedule.isEnabled {
            SettingsPropertyRow("schedule_from") {
                DatePicker(selection: startTimeBinding, displayedComponents: .hourAndMinute) {
                    Text("schedule_from")
                }
                .labelsHidden()
            }

            SettingsPropertyRow("schedule_to") {
                DatePicker(selection: endTimeBinding, displayedComponents: .hourAndMinute) {
                    Text("schedule_to")
                }
                .labelsHidden()
            }

            SettingsPropertyRow("weekdays_only") {
                Toggle(isOn: $preferencesStore.preferences.schedule.weekdaysOnly) {
                    Text("weekdays_only")
                }
                .labelsHidden()
            }
        }
    }

    @ViewBuilder
    private var scheduleFooter: some View {
        if preferencesStore.preferences.schedule.isEnabled && !isValidTimeRange {
            Text("schedule_invalid")
                .foregroundStyle(.red)
        } else if preferencesStore.preferences.schedule.isEnabled {
            Text("schedule_footer")
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        Section {
            workHoursRows

            SettingsPropertyRow("overlay_display") {
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
                .labelsHidden()
                .pickerStyle(.menu)
            }

            SettingsPropertyRow("expand_notch") {
                Toggle(isOn: $preferencesStore.preferences.notchExpansionEnabled) {
                    Text("expand_notch")
                }
                .labelsHidden()
            }

            SettingsPropertyRow("show_hover_preview") {
                Toggle(isOn: $preferencesStore.preferences.hoverPreviewEnabled) {
                    Text("show_hover_preview")
                }
                .labelsHidden()
            }

            SettingsPropertyRow("play_sound") {
                Toggle(isOn: $preferencesStore.preferences.soundEnabled) {
                    Text("play_sound")
                }
                .labelsHidden()
            }

            SettingsPropertyRow("auto_dismiss") {
                Toggle(isOn: $preferencesStore.preferences.autoDismissEnabled) {
                    Text("auto_dismiss")
                }
                .labelsHidden()
            }

            if preferencesStore.preferences.autoDismissEnabled {
                SettingsPropertyRow("dismiss_after") {
                    Picker(selection: $preferencesStore.preferences.autoDismissSeconds) {
                        ForEach(Self.dismissOptions, id: \.self) { seconds in
                            Text(String(format: localizedString("seconds_format"), seconds))
                                .tag(seconds)
                        }
                    } label: {
                        Text("dismiss_after")
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(maxWidth: 140, alignment: .leading)
                }
            }
        } header: {
            sectionHeader("section.behavior")
        } footer: {
            if preferencesStore.preferences.schedule.isEnabled && !isValidTimeRange {
                Text("schedule_invalid")
                    .foregroundStyle(.red)
            } else {
                Text("behavior_footer")
            }
        }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        Section {
            SettingsPropertyRow("breaks_today") {
                Text("\(breakStatsStore.todayBreaks)")
                    .monospacedDigit()
            }

            SettingsPropertyRow("breaks_this_week") {
                Text("\(breakStatsStore.weekBreaks)")
                    .monospacedDigit()
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
                    showingRestoreConfirmation = true
                } label: {
                    Text("restore_defaults")
                }
                .confirmationDialog(
                    Text("restore_confirm"),
                    isPresented: $showingRestoreConfirmation,
                    titleVisibility: .visible
                ) {
                    Button(role: .destructive) { restoreDefaults() } label: {
                        Text("restore_action")
                    }
                    Button(role: .cancel) {} label: {
                        Text("cancel")
                    }
                }
            }
            .padding(.top, 4)
        } header: {
            sectionHeader("section.statistics")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            SettingsPropertyRow("version") {
                Text(appVersion)
            }

            SettingsPropertyRow("current_language") {
                Text(currentLanguageDisplayName)
            }

            Text("app_description")
                .font(.callout)
                .foregroundStyle(.secondary)
        } header: {
            sectionHeader("section.about")
        }
    }

    // MARK: - Helpers

    private var sitAwareCaptionKey: String {
        preferencesStore.preferences.sitAwareEnabled ? "sit_aware_footer_on" : "sit_aware_footer_off"
    }

    private var aiSettingsPrivacyFooterKey: String {
        aiProviderPreferences.selectedTranscriptionProvider == .localWhisperKit
            ? "ai.settings.privacy_footer_local_transcription"
            : "ai.settings.privacy_footer"
    }

    private var selectedLocalSpeechModel: LocalSpeechModelID? {
        LocalSpeechModelID(rawValue: aiProviderPreferences.transcriptionModel)
    }

    private var selectedLocalModelState: LocalSpeechModelState {
        guard let selectedLocalSpeechModel else { return .notDownloaded }
        return localSpeechModelStore.state(for: selectedLocalSpeechModel)
    }

    private var isLocalModelBusy: Bool {
        selectedLocalModelState.isBusy
    }

    private var canDeleteLocalModel: Bool {
        guard selectedLocalSpeechModel != nil else { return false }

        switch selectedLocalModelState {
        case .notDownloaded, .downloading, .verifying:
            return false
        case .ready, .failed:
            return true
        }
    }

    private var localModelStatusColor: Color {
        switch selectedLocalModelState {
        case .ready:
            .green
        case .failed:
            .red
        case .notDownloaded, .downloading, .verifying:
            .secondary
        }
    }

    private var localModelStatusText: String {
        switch selectedLocalModelState {
        case .notDownloaded:
            return localizedString("ai.settings.local_model_status_not_downloaded")
        case .downloading(let progress):
            if let progress {
                return String(
                    format: localizedString("ai.settings.local_model_status_downloading_format"),
                    Int(progress * 100)
                )
            }
            return localizedString("ai.settings.local_model_status_downloading")
        case .verifying:
            return localizedString("ai.settings.local_model_status_verifying")
        case .ready:
            return localizedString("ai.settings.local_model_status_ready")
        case .failed(let message):
            return String(format: localizedString("ai.settings.local_model_status_failed_format"), message)
        }
    }

    private var launchAtLoginBinding: Binding<Bool> {
        Binding(
            get: { preferencesStore.preferences.launchAtLoginEnabled },
            set: { setLaunchAtLoginEnabled($0) }
        )
    }

    private var transcriptionProviderBinding: Binding<String> {
        Binding(
            get: { aiProviderPreferences.selectedTranscriptionProvider.rawValue },
            set: { providerID in
                guard let provider = AIProviderID(rawValue: providerID) else { return }
                aiProviderPreferences.selectTranscriptionProvider(provider)
                loadAPIKeys()
            }
        )
    }

    private var parserProviderBinding: Binding<String> {
        Binding(
            get: { aiProviderPreferences.selectedParserProvider.rawValue },
            set: { providerID in
                guard let provider = AIProviderID(rawValue: providerID) else { return }
                aiProviderPreferences.selectParserProvider(provider)
                loadAPIKeys()
            }
        )
    }

    private func credentialBinding(for request: AICredentialRequest) -> Binding<String> {
        Binding(
            get: { credentials[credentialStateKey(for: request), default: ""] },
            set: { credentials[credentialStateKey(for: request)] = $0 }
        )
    }

    private func credentialTitle(for request: AICredentialRequest) -> String {
        String(
            format: localizedString("ai.settings.provider_key_format"),
            "\(request.provider.displayName) \(request.field.displayName)"
        )
    }

    private func credentialRow(for request: AICredentialRequest) -> some View {
        SettingsDynamicPropertyRow(
            credentialTitle(for: request),
            captionKey: "ai.settings.provider_key_caption"
        ) {
            HStack(spacing: 8) {
                if request.field.isSecret {
                    SecureField(credentialTitle(for: request), text: credentialBinding(for: request))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                } else {
                    TextField(credentialTitle(for: request), text: credentialBinding(for: request))
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 260)
                }

                Button("ai.settings.save_key") {
                    saveCredential(for: request)
                }

                Button(role: .destructive) {
                    credentials[credentialStateKey(for: request)] = ""
                    saveCredential(for: request)
                } label: {
                    Text("ai.settings.clear_key")
                }
                .disabled(credentials[credentialStateKey(for: request), default: ""].isEmpty)

                Button {
                    setupGuideProvider = request.provider
                } label: {
                    Label("ai.settings.provider_guide", systemImage: "questionmark.circle")
                        .labelStyle(.iconOnly)
                }
                .buttonStyle(.borderless)
                .help(Text("ai.settings.provider_guide_help"))
            }
        }
    }

    private func credentialStateKey(for request: AICredentialRequest) -> String {
        "\(request.provider.rawValue).\(request.field.id)"
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

    private func loadAPIKeys() {
        do {
            for provider in AIProviderID.allCases {
                for field in provider.definition.credentialFields {
                    let request = AICredentialRequest(provider: provider, field: field)
                    credentials[credentialStateKey(for: request)] = try aiProviderPreferences.credential(field.id, for: provider) ?? ""
                }
            }
            apiKeyStatusMessage = nil
        } catch {
            apiKeyStatusMessage = error.localizedDescription
        }
    }

    private func saveCredential(for request: AICredentialRequest) {
        do {
            try aiProviderPreferences.saveCredential(
                credentials[credentialStateKey(for: request), default: ""],
                fieldID: request.field.id,
                for: request.provider
            )
            apiKeyStatusMessage = String(
                format: localizedString("ai.settings.key_saved_format"),
                "\(request.provider.displayName) \(request.field.displayName)"
            )
        } catch {
            apiKeyStatusMessage = error.localizedDescription
        }
    }

    private func refreshLocalModelState() {
        guard aiProviderPreferences.selectedTranscriptionProvider == .localWhisperKit,
              let selectedLocalSpeechModel
        else {
            return
        }

        localSpeechModelStore.refreshState(for: selectedLocalSpeechModel)
    }

    private func downloadLocalModel() {
        guard let selectedLocalSpeechModel else { return }
        apiKeyStatusMessage = nil

        Task {
            await localSpeechModelStore.download(selectedLocalSpeechModel)
        }
    }

    private func verifyLocalModel() {
        guard let selectedLocalSpeechModel else { return }
        localSpeechModelStore.verify(selectedLocalSpeechModel)
    }

    private func deleteLocalModel() {
        guard let selectedLocalSpeechModel else { return }

        do {
            try localSpeechModelStore.delete(selectedLocalSpeechModel)
            apiKeyStatusMessage = localizedString("ai.settings.local_model_deleted")
        } catch {
            apiKeyStatusMessage = error.localizedDescription
        }
    }

    private func testTranscriptionProvider() {
        isTestingTranscriptionProvider = true
        apiKeyStatusMessage = nil

        Task {
            defer {
                isTestingTranscriptionProvider = false
            }

            do {
                _ = try AIProviderFactory.makeTranscriptionProvider(preferences: aiProviderPreferences)
                apiKeyStatusMessage = localizedString("ai.settings.test_transcription_succeeded")
            } catch {
                apiKeyStatusMessage = error.localizedDescription
            }
        }
    }

    private func testParserProvider() {
        isTestingParserProvider = true
        apiKeyStatusMessage = nil

        Task {
            defer {
                isTestingParserProvider = false
            }

            do {
                let parserProvider = try AIProviderFactory.makeParserProvider(preferences: aiProviderPreferences)
                _ = try await parserProvider.parseSchedule(
                    transcript: Transcript(text: "No schedule items.", language: "en", duration: nil),
                    context: ScheduleParseContext(
                        currentDate: .now,
                        timeZone: .current,
                        localeIdentifier: languageManager.locale.identifier,
                        appLanguage: languageManager.selectedLanguage,
                        defaultReminderLeadMinutes: aiProviderPreferences.defaultReminderLeadMinutes,
                        existingScheduleItems: []
                    )
                )
                apiKeyStatusMessage = localizedString("ai.settings.test_succeeded")
            } catch {
                apiKeyStatusMessage = error.localizedDescription
            }
        }
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

private struct AIProviderSetupGuideSheet: View {
    let provider: AIProviderID
    let guide: AIProviderSetupGuide
    let languageManager: LanguageManager

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(title)
                            .font(.title3.weight(.semibold))

                        Spacer()

                        Button {
                            dismiss()
                        } label: {
                            Label("ai.guide.close", systemImage: "xmark.circle.fill")
                                .labelStyle(.iconOnly)
                        }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                        .help(Text("ai.guide.close"))
                    }

                    Text(LocalizedStringKey(guide.overviewKey))
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("ai.guide.required_fields")
                            .font(.headline)

                        Text(requiredFieldsText)
                            .font(.system(size: 13))
                            .textSelection(.enabled)
                    }

                    if guide.documentationURL != nil || guide.consoleURL != nil {
                        HStack(spacing: 8) {
                            if let documentationURL = guide.documentationURL {
                                Link(destination: documentationURL) {
                                    Label("ai.guide.official_docs", systemImage: "book")
                                }
                            }

                            if let consoleURL = guide.consoleURL {
                                Link(destination: consoleURL) {
                                    Label("ai.guide.provider_console", systemImage: "safari")
                                }
                            }
                        }
                        .controlSize(.small)
                    }

                    Divider()

                    VStack(alignment: .leading, spacing: 8) {
                        Text("ai.guide.steps")
                            .font(.headline)

                        Text(LocalizedStringKey(guide.stepsKey))
                            .font(.system(size: 13))
                            .lineSpacing(4)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider()

                    Label {
                        Text("ai.guide.security_body")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    } icon: {
                        Image(systemName: "lock")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()

            HStack {
                Spacer()

                Button("ai.guide.close") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 520)
        .frame(minHeight: 360, maxHeight: 640)
    }

    private var title: String {
        String(
            format: languageManager.localizedString("ai.guide.title_format"),
            provider.displayName
        )
    }

    private var requiredFieldsText: String {
        guide.requiredFieldNames.joined(separator: " · ")
    }
}

private struct SettingsPropertyRow<Content: View>: View {
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 16) {
                Text(LocalizedStringKey(titleKey))
                    .foregroundStyle(.secondary)
                    .frame(width: 168, alignment: .leading)

                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let captionKey {
                Text(LocalizedStringKey(captionKey))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 184)
            }
        }
        .font(.system(size: 13))
        .padding(.vertical, 4)
    }
}

private struct SettingsDynamicPropertyRow<Content: View>: View {
    let title: String
    let captionKey: String?
    let content: Content

    init(
        _ title: String,
        captionKey: String? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.captionKey = captionKey
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 16) {
                Text(title)
                    .foregroundStyle(.secondary)
                    .frame(width: 168, alignment: .leading)

                content
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let captionKey {
                Text(LocalizedStringKey(captionKey))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .padding(.leading, 184)
            }
        }
        .font(.system(size: 13))
        .padding(.vertical, 4)
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
        aiProviderPreferences: AIProviderPreferences(defaults: settings.defaults),
        breakStatsStore: breakStatsStore
    )
        .frame(width: 420, height: 600)
}
