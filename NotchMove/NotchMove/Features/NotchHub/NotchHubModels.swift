//
//  NotchHubModels.swift
//  NotchMove
//
//  Created by Codex on 6/6/26.
//

import AppKit
import Foundation
import Observation

enum NotchHubWidgetGroup: String, CaseIterable, Hashable, Identifiable {
    case core
    case optional
    case advanced

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .core: "notch_hub.group.core"
        case .optional: "notch_hub.group.optional"
        case .advanced: "notch_hub.group.advanced"
        }
    }
}

enum NotchHubWidgetID: String, CaseIterable, Codable, Hashable, Identifiable {
    case live
    case media
    case calendar
    case shortcuts
    case notes
    case mirror
    case tray

    var id: String { rawValue }

    static let coreDefaultWidgets: Set<NotchHubWidgetID> = [.live, .calendar, .notes]

    static func widgets(in group: NotchHubWidgetGroup) -> [NotchHubWidgetID] {
        allCases.filter { $0.group == group }
    }

    var group: NotchHubWidgetGroup {
        switch self {
        case .live, .calendar, .notes:
            .core
        case .media:
            .optional
        case .shortcuts, .mirror, .tray:
            .advanced
        }
    }

    var titleKey: String {
        switch self {
        case .live: "notch_hub.widget.live"
        case .media: "notch_hub.widget.media"
        case .calendar: "notch_hub.widget.calendar"
        case .shortcuts: "notch_hub.widget.shortcuts"
        case .notes: "notch_hub.widget.notes"
        case .mirror: "notch_hub.widget.mirror"
        case .tray: "notch_hub.widget.tray"
        }
    }

    var systemImage: String {
        switch self {
        case .live: "waveform.path.ecg"
        case .media: "play.circle"
        case .calendar: "calendar"
        case .shortcuts: "command"
        case .notes: "note.text"
        case .mirror: "camera.viewfinder"
        case .tray: "tray.full"
        }
    }

    var requiredPermission: NotchHubPermission? {
        switch self {
        case .live, .calendar, .notes:
            nil
        case .media:
            .appleEvents
        case .shortcuts:
            .shortcuts
        case .mirror:
            .camera
        case .tray:
            .files
        }
    }

    var isSensitiveIntegration: Bool {
        requiredPermission != nil
    }
}

enum NotchHubPermission: String, CaseIterable, Codable, Hashable, Identifiable {
    case appleEvents
    case calendar
    case shortcuts
    case camera
    case files

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .appleEvents: "notch_hub.permission.apple_events"
        case .calendar: "notch_hub.permission.calendar"
        case .shortcuts: "notch_hub.permission.shortcuts"
        case .camera: "notch_hub.permission.camera"
        case .files: "notch_hub.permission.files"
        }
    }
}

enum NotchHubPresentation: Equatable {
    case tucked
    case peek
    case expanded
    case widget(NotchHubWidgetID)
    case permissionPrompt(NotchHubPermission)
    case transientError(String)

    var isExpandedSurface: Bool {
        switch self {
        case .expanded, .widget, .permissionPrompt, .transientError:
            true
        case .tucked, .peek:
            false
        }
    }
}

enum NotchHubEffectiveSurface: Equatable {
    case voice
    case reminder
    case hub
    case liveStatus
    case hoverPreview
    case tucked
}

enum NotchHubPresentationResolver {
    static func effectiveSurface(
        voiceOverlayVisible: Bool,
        reminderPresentation: ReminderState.PresentationPhase,
        hubPresentation: NotchHubPresentation,
        pomodoroActive: Bool,
        hoverPreviewEnabled: Bool
    ) -> NotchHubEffectiveSurface {
        if voiceOverlayVisible {
            return .voice
        }

        switch reminderPresentation {
        case .reminderPending, .presenting, .dismissAnimating:
            return .reminder
        case .hidden, .hoverPreviewPending, .hoverPreview, .hoverPreviewDismissing:
            break
        }

        if hubPresentation.isExpandedSurface {
            return .hub
        }

        if pomodoroActive {
            return .liveStatus
        }

        if hoverPreviewEnabled {
            switch reminderPresentation {
            case .hoverPreviewPending, .hoverPreview, .hoverPreviewDismissing:
                return .hoverPreview
            case .hidden, .reminderPending, .presenting, .dismissAnimating:
                break
            }
        }

        return .tucked
    }
}

enum NotchHubTriggerGesture: String, CaseIterable, Codable, Identifiable {
    case click
    case hoverAndClick

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .click: "notch_hub.trigger.click"
        case .hoverAndClick: "notch_hub.trigger.hover_click"
        }
    }
}

private enum FileDropLoadResult: Sendable {
    case fileURL(URL)
    case fileURLData(Data)
    case failure(String)
    case unsupported
}

struct NotchHubFocusOverviewSnapshot: Equatable {
    let nextLocalScheduleItem: DailyScheduleItem?

    init(scheduleItems: [DailyScheduleItem], at date: Date) {
        nextLocalScheduleItem = Self.nextLocalScheduleItem(in: scheduleItems, at: date)
    }

    private static func nextLocalScheduleItem(
        in items: [DailyScheduleItem],
        at date: Date
    ) -> DailyScheduleItem? {
        items
            .filter { $0.isReminderEnabled && ($0.endDate ?? $0.startDate) >= date }
            .sorted { $0.startDate < $1.startDate }
            .first
    }
}

struct NotchHubPreferences: Equatable {
    var isEnabled: Bool
    var enabledWidgetIDs: Set<NotchHubWidgetID>
    var defaultWidgetID: NotchHubWidgetID
    var triggerGesture: NotchHubTriggerGesture
    var allowAppleEvents: Bool
    var allowCalendarAccess: Bool
    var allowCameraAccess: Bool
    var allowFileTray: Bool
    var shortcutNames: [String]

    static let defaults = NotchHubPreferences(
        isEnabled: false,
        enabledWidgetIDs: NotchHubWidgetID.coreDefaultWidgets,
        defaultWidgetID: .live,
        triggerGesture: .click,
        allowAppleEvents: false,
        allowCalendarAccess: false,
        allowCameraAccess: false,
        allowFileTray: false,
        shortcutNames: []
    )
}

private enum NotchHubPreferenceKeys {
    static let isEnabled = "notchHub.isEnabled"
    static let enabledWidgetIDs = "notchHub.enabledWidgetIDs"
    static let defaultWidgetID = "notchHub.defaultWidgetID"
    static let triggerGesture = "notchHub.triggerGesture"
    static let allowAppleEvents = "notchHub.allowAppleEvents"
    static let allowCalendarAccess = "notchHub.allowCalendarAccess"
    static let allowCameraAccess = "notchHub.allowCameraAccess"
    static let allowFileTray = "notchHub.allowFileTray"
    static let shortcutNames = "notchHub.shortcutNames"
}

@MainActor
@Observable
final class NotchHubStore {
    let dailyScheduleStore: DailyScheduleStore
    let mediaProvider: any MediaControlProviding
    let calendarProvider: any CalendarEventProviding
    let shortcutsProvider: any ShortcutRunning
    let quickNotesStore: QuickNotesStore
    let fileTrayStore: FileTrayStore
    let cameraPermissionProvider: any CameraPermissionProviding

    private let defaults: UserDefaults
    @ObservationIgnored private var isNormalizingPreferences = false

    var preferences: NotchHubPreferences {
        didSet {
            guard !isNormalizingPreferences else {
                savePreferences()
                return
            }

            let normalizedPreferences = normalized(preferences)
            if normalizedPreferences != preferences {
                isNormalizingPreferences = true
                preferences = normalizedPreferences
                isNormalizingPreferences = false
            }
            savePreferences()
        }
    }

    var presentation: NotchHubPresentation = .tucked
    var selectedWidgetID: NotchHubWidgetID
    var mediaStatus = MediaPlaybackStatus()
    var upcomingCalendarItems: [NotchHubCalendarItem] = []
    var lastActionMessage: String?

    init(
        defaults: UserDefaults = .standard,
        dailyScheduleStore: DailyScheduleStore,
        mediaProvider: any MediaControlProviding = SystemMediaControlProvider(),
        calendarProvider: any CalendarEventProviding = SystemCalendarEventProvider(),
        shortcutsProvider: any ShortcutRunning = SystemShortcutRunner(),
        quickNotesStore: QuickNotesStore? = nil,
        fileTrayStore: FileTrayStore? = nil,
        cameraPermissionProvider: any CameraPermissionProviding = SystemCameraPermissionProvider()
    ) {
        self.defaults = defaults
        self.dailyScheduleStore = dailyScheduleStore
        self.mediaProvider = mediaProvider
        self.calendarProvider = calendarProvider
        self.shortcutsProvider = shortcutsProvider
        self.quickNotesStore = quickNotesStore ?? QuickNotesStore(defaults: defaults)
        self.fileTrayStore = fileTrayStore ?? FileTrayStore(defaults: defaults)
        self.cameraPermissionProvider = cameraPermissionProvider
        let loadedPreferences = Self.loadPreferences(from: defaults)
        let initialPreferences = Self.normalized(loadedPreferences)
        preferences = initialPreferences
        selectedWidgetID = initialPreferences.defaultWidgetID
    }

    var enabledWidgets: [NotchHubWidgetID] {
        NotchHubWidgetID.allCases.filter { preferences.enabledWidgetIDs.contains($0) }
    }

    var activeWidgetID: NotchHubWidgetID {
        switch presentation {
        case .widget(let widgetID):
            widgetID
        case .tucked, .peek, .expanded, .permissionPrompt, .transientError:
            selectedWidgetID
        }
    }

    var isExpanded: Bool {
        presentation.isExpandedSurface
    }

    var requiresKeyWindow: Bool {
        isExpanded
    }

    func focusOverviewSnapshot(at date: Date) -> NotchHubFocusOverviewSnapshot {
        NotchHubFocusOverviewSnapshot(
            scheduleItems: dailyScheduleStore.items,
            at: date
        )
    }

    func toggleHub() {
        guard preferences.isEnabled else { return }

        if isExpanded {
            collapse()
        } else {
            open()
        }
    }

    func setHubEnabled(_ isEnabled: Bool) {
        preferences.isEnabled = isEnabled

        if isEnabled {
            normalizeSelection()
        } else {
            collapse()
        }
    }

    func open() {
        guard preferences.isEnabled else { return }
        normalizeSelection()
        presentation = .widget(selectedWidgetID)
        refreshActiveWidget()
    }

    func collapse() {
        presentation = .tucked
        lastActionMessage = nil
    }

    func selectWidget(_ widgetID: NotchHubWidgetID) {
        guard preferences.enabledWidgetIDs.contains(widgetID) else { return }
        selectedWidgetID = widgetID
        presentation = .widget(widgetID)
        refreshActiveWidget()
    }

    func setWidget(_ widgetID: NotchHubWidgetID, enabled: Bool) {
        guard widgetID != .live || enabled else { return }

        let wasActiveExpandedWidget = isExpanded && activeWidgetID == widgetID

        if enabled {
            preferences.enabledWidgetIDs.insert(widgetID)
        } else {
            preferences.enabledWidgetIDs.remove(widgetID)
        }
        normalizeSelection()

        if wasActiveExpandedWidget && !preferences.enabledWidgetIDs.contains(widgetID) {
            presentation = .widget(selectedWidgetID)
            refreshActiveWidget()
        }
    }

    func setDefaultWidget(_ widgetID: NotchHubWidgetID) {
        guard preferences.enabledWidgetIDs.contains(widgetID) else { return }
        preferences.defaultWidgetID = widgetID
        selectedWidgetID = widgetID
    }

    func refreshActiveWidget() {
        switch activeWidgetID {
        case .media:
            guard preferences.allowAppleEvents else {
                mediaStatus = MediaPlaybackStatus()
                return
            }
            Task { await refreshMediaStatus() }
        case .calendar:
            Task { await refreshCalendarItems() }
        case .live, .shortcuts, .notes, .mirror, .tray:
            break
        }
    }

    func refreshMediaStatus() async {
        guard preferences.allowAppleEvents else {
            mediaStatus = MediaPlaybackStatus()
            return
        }

        mediaStatus = await mediaProvider.currentStatus()
    }

    func performMediaCommand(_ command: MediaControlCommand) {
        guard preferences.allowAppleEvents else {
            presentation = .permissionPrompt(.appleEvents)
            return
        }

        Task {
            let result = await mediaProvider.perform(command)
            await refreshMediaStatus()
            apply(result)
        }
    }

    func refreshCalendarItems() async {
        upcomingCalendarItems = calendarProvider.localScheduleItems(from: dailyScheduleStore.items)

        guard preferences.allowCalendarAccess else { return }
        let externalItems = await calendarProvider.upcomingExternalItems(limit: 4)
        upcomingCalendarItems = Array((upcomingCalendarItems + externalItems).sorted { $0.startDate < $1.startDate }.prefix(6))
    }

    func requestCalendarAccess() {
        Task {
            let granted = await calendarProvider.requestAccess()
            preferences.allowCalendarAccess = granted
            await refreshCalendarItems()
        }
    }

    func requestCameraAccess() {
        Task {
            let granted = await cameraPermissionProvider.requestAccess()
            preferences.allowCameraAccess = granted
        }
    }

    func addShortcut(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty,
              !preferences.shortcutNames.contains(trimmedName)
        else {
            return
        }

        preferences.shortcutNames.append(trimmedName)
    }

    func removeShortcut(named name: String) {
        preferences.shortcutNames.removeAll { $0 == name }
    }

    func runShortcut(named name: String) {
        Task {
            let result = await shortcutsProvider.runShortcut(named: name)
            apply(result)
        }
    }

    func addFileItemProviders(_ providers: [NSItemProvider]) -> Bool {
        guard preferences.allowFileTray else {
            presentation = .permissionPrompt(.files)
            return false
        }

        var didStartLoading = false
        for provider in providers where provider.hasItemConformingToTypeIdentifier(FileTrayStore.fileURLTypeIdentifier) {
            didStartLoading = true
            provider.loadItem(forTypeIdentifier: FileTrayStore.fileURLTypeIdentifier, options: nil) { [weak self] item, error in
                let result = Self.fileDropLoadResult(item: item, error: error)
                Task { @MainActor [weak self] in
                    self?.handleLoadedFileDropResult(result)
                }
            }
        }
        return didStartLoading
    }

    func addFileURLs(_ urls: [URL]) {
        do {
            try fileTrayStore.add(urls)
        } catch {
            presentation = .transientError(error.localizedDescription)
        }
    }

    func openFileTrayItem(_ item: FileTrayItem) {
        fileTrayStore.open(item)
    }

    func revealFileTrayItem(_ item: FileTrayItem) {
        fileTrayStore.reveal(item)
    }

    func shareFileTrayItemViaAirDrop(_ item: FileTrayItem) {
        do {
            try fileTrayStore.shareViaAirDrop(item)
        } catch {
            presentation = .transientError(error.localizedDescription)
        }
    }

    private nonisolated static func fileDropLoadResult(
        item: NSSecureCoding?,
        error: Error?
    ) -> FileDropLoadResult {
        if let error {
            return .failure(error.localizedDescription)
        }

        if let url = item as? URL {
            return .fileURL(url)
        }

        if let data = item as? Data {
            return .fileURLData(data)
        }

        return .unsupported
    }

    private func handleLoadedFileDropResult(_ result: FileDropLoadResult) {
        switch result {
        case .fileURL(let url):
            addFileURLs([url])
        case .fileURLData(let data):
            if let url = URL(dataRepresentation: data, relativeTo: nil) {
                addFileURLs([url])
            }
        case .failure(let message):
            presentation = .transientError(message)
        case .unsupported:
            break
        }
    }

    private func apply(_ result: NotchHubActionResult) {
        switch result {
        case .success(let message):
            lastActionMessage = message
        case .failure(let message):
            presentation = .transientError(message)
        }
    }

    private func normalizeSelection() {
        preferences = normalized(preferences)
        if !preferences.enabledWidgetIDs.contains(selectedWidgetID) {
            selectedWidgetID = preferences.defaultWidgetID
        }
    }

    private func normalized(_ preferences: NotchHubPreferences) -> NotchHubPreferences {
        Self.normalized(preferences)
    }

    private static func normalized(_ preferences: NotchHubPreferences) -> NotchHubPreferences {
        var normalized = preferences
        let validWidgets = Set(NotchHubWidgetID.allCases)
        normalized.enabledWidgetIDs = normalized.enabledWidgetIDs.intersection(validWidgets)
        normalized.enabledWidgetIDs.insert(.live)

        if !normalized.enabledWidgetIDs.contains(normalized.defaultWidgetID) {
            normalized.defaultWidgetID = normalized.enabledWidgetIDs.contains(.live) ?
                .live :
                (normalized.enabledWidgetIDs.sorted { $0.rawValue < $1.rawValue }.first ?? .live)
        }

        normalized.shortcutNames = normalized.shortcutNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .uniqued()

        return normalized
    }

    private static func loadPreferences(from defaults: UserDefaults) -> NotchHubPreferences {
        let fallback = NotchHubPreferences.defaults
        let widgetIDs = defaults.stringArray(forKey: NotchHubPreferenceKeys.enabledWidgetIDs)?
            .compactMap(NotchHubWidgetID.init(rawValue:))
        let defaultWidget = defaults.string(forKey: NotchHubPreferenceKeys.defaultWidgetID)
            .flatMap(NotchHubWidgetID.init(rawValue:)) ?? fallback.defaultWidgetID
        let triggerGesture = defaults.string(forKey: NotchHubPreferenceKeys.triggerGesture)
            .flatMap(NotchHubTriggerGesture.init(rawValue:)) ?? fallback.triggerGesture

        return NotchHubPreferences(
            isEnabled: defaults.object(forKey: NotchHubPreferenceKeys.isEnabled) as? Bool ?? fallback.isEnabled,
            enabledWidgetIDs: Set(widgetIDs ?? Array(fallback.enabledWidgetIDs)),
            defaultWidgetID: defaultWidget,
            triggerGesture: triggerGesture,
            allowAppleEvents: defaults.object(forKey: NotchHubPreferenceKeys.allowAppleEvents) as? Bool ?? fallback.allowAppleEvents,
            allowCalendarAccess: defaults.object(forKey: NotchHubPreferenceKeys.allowCalendarAccess) as? Bool ?? fallback.allowCalendarAccess,
            allowCameraAccess: defaults.object(forKey: NotchHubPreferenceKeys.allowCameraAccess) as? Bool ?? fallback.allowCameraAccess,
            allowFileTray: defaults.object(forKey: NotchHubPreferenceKeys.allowFileTray) as? Bool ?? fallback.allowFileTray,
            shortcutNames: defaults.stringArray(forKey: NotchHubPreferenceKeys.shortcutNames) ?? fallback.shortcutNames
        )
    }

    private func savePreferences() {
        defaults.set(preferences.isEnabled, forKey: NotchHubPreferenceKeys.isEnabled)
        defaults.set(preferences.enabledWidgetIDs.map(\.rawValue).sorted(), forKey: NotchHubPreferenceKeys.enabledWidgetIDs)
        defaults.set(preferences.defaultWidgetID.rawValue, forKey: NotchHubPreferenceKeys.defaultWidgetID)
        defaults.set(preferences.triggerGesture.rawValue, forKey: NotchHubPreferenceKeys.triggerGesture)
        defaults.set(preferences.allowAppleEvents, forKey: NotchHubPreferenceKeys.allowAppleEvents)
        defaults.set(preferences.allowCalendarAccess, forKey: NotchHubPreferenceKeys.allowCalendarAccess)
        defaults.set(preferences.allowCameraAccess, forKey: NotchHubPreferenceKeys.allowCameraAccess)
        defaults.set(preferences.allowFileTray, forKey: NotchHubPreferenceKeys.allowFileTray)
        defaults.set(preferences.shortcutNames, forKey: NotchHubPreferenceKeys.shortcutNames)
    }
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen = Set<Element>()
        return filter { seen.insert($0).inserted }
    }
}
