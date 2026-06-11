//
//  DiagnosticsReportService.swift
//  NotchMove
//
//  Created by Codex on 6/11/26.
//

import AppKit
import AVFoundation
import Foundation

struct DiagnosticsReport: Codable, Equatable {
    struct AppSnapshot: Codable, Equatable {
        var version: String
        var build: String
        var osVersion: String
        var generatedAt: Date
    }

    struct PreferencesSnapshot: Codable, Equatable {
        var soundEnabled: Bool
        var launchAtLoginEnabled: Bool
        var breakReminderEnabled: Bool
        var pomodoroEnabled: Bool
        var reminderIntervalMinutes: Int
        var sitAwareEnabled: Bool
        var hoverPreviewEnabled: Bool
        var autoDismissEnabled: Bool
        var autoDismissSeconds: Int
        var appLanguage: String
        var overlayDisplayMode: String
        var voiceInputEnabled: Bool
        var voiceInputShortcutID: String
        var voiceCleanupMode: String
        var voicePersonalTermsCount: Int
    }

    struct PermissionSnapshot: Codable, Equatable {
        var microphone: String
        var speechRecognition: String
        var accessibility: String
        var notchHubAppleEventsAllowed: Bool
        var notchHubCalendarAllowed: Bool
        var notchHubCameraAllowed: Bool
        var notchHubFileTrayAllowed: Bool
    }

    struct ReminderSnapshot: Codable, Equatable {
        var runState: String?
        var presentation: String?
        var manualPause: Bool?
        var manualPauseUntilDate: Date?
        var breakSnoozedUntilDate: Date?
        var reminderIntervalSeconds: TimeInterval?
    }

    struct PomodoroSnapshot: Codable, Equatable {
        var isActive: Bool?
        var isPaused: Bool?
        var remainingSeconds: Int?
        var phase: String?
    }

    struct NotchHubSnapshot: Codable, Equatable {
        var isEnabled: Bool
        var presentation: String
        var defaultWidgetID: String
        var enabledWidgetIDs: [String]
        var triggerGesture: String
    }

    struct AISnapshot: Codable, Equatable {
        var aiEnabled: Bool
        var transcriptionProvider: String
        var transcriptionModel: String
        var parserProvider: String
        var parserModel: String
        var languageMode: String
        var customParserBaseURLConfigured: Bool
    }

    struct ScreenSnapshot: Codable, Equatable {
        var displayID: UInt32
        var localizedName: String
        var isBuiltIn: Bool
        var frame: String
        var hasNotchFrame: Bool
        var menuBarHeight: Double
    }

    var app: AppSnapshot
    var preferences: PreferencesSnapshot
    var permissions: PermissionSnapshot
    var reminder: ReminderSnapshot
    var pomodoro: PomodoroSnapshot
    var notchHub: NotchHubSnapshot
    var ai: AISnapshot
    var screens: [ScreenSnapshot]
}

@MainActor
struct DiagnosticsReportService {
    let preferencesStore: PreferencesStore
    let aiProviderPreferences: AIProviderPreferences
    let breakStatsStore: BreakStatsStore
    let notchHubStore: NotchHubStore
    let reminderEngine: ReminderEngine?
    let pomodoroEngine: PomodoroEngine?
    let screens: [ScreenDescriptor]
    var dateProvider: () -> Date = Date.init

    func makeReport() -> DiagnosticsReport {
        let preferences = preferencesStore.preferences

        return DiagnosticsReport(
            app: DiagnosticsReport.AppSnapshot(
                version: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown",
                build: Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "unknown",
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                generatedAt: dateProvider()
            ),
            preferences: DiagnosticsReport.PreferencesSnapshot(
                soundEnabled: preferences.soundEnabled,
                launchAtLoginEnabled: preferences.launchAtLoginEnabled,
                breakReminderEnabled: preferences.breakReminderEnabled,
                pomodoroEnabled: preferences.pomodoroEnabled,
                reminderIntervalMinutes: preferences.reminderIntervalMinutes,
                sitAwareEnabled: preferences.sitAwareEnabled,
                hoverPreviewEnabled: preferences.hoverPreviewEnabled,
                autoDismissEnabled: preferences.autoDismissEnabled,
                autoDismissSeconds: preferences.autoDismissSeconds,
                appLanguage: preferences.appLanguage,
                overlayDisplayMode: overlayDisplayModeDescription(preferences.overlayDisplayMode),
                voiceInputEnabled: preferences.voiceInputEnabled,
                voiceInputShortcutID: preferences.voiceInputShortcutID,
                voiceCleanupMode: preferences.voiceCleanupMode.rawValue,
                voicePersonalTermsCount: preferences.voicePersonalTerms.count
            ),
            permissions: DiagnosticsReport.PermissionSnapshot(
                microphone: microphoneAuthorizationDescription(AVCaptureDevice.authorizationStatus(for: .audio)),
                speechRecognition: speechAuthorizationDescription(AppleSpeechTranscriptionProvider.authorizationState()),
                accessibility: AccessibilityPermissionService.isTrusted ? "authorized" : "notTrusted",
                notchHubAppleEventsAllowed: notchHubStore.preferences.allowAppleEvents,
                notchHubCalendarAllowed: notchHubStore.preferences.allowCalendarAccess,
                notchHubCameraAllowed: notchHubStore.preferences.allowCameraAccess,
                notchHubFileTrayAllowed: notchHubStore.preferences.allowFileTray
            ),
            reminder: reminderSnapshot(),
            pomodoro: pomodoroSnapshot(),
            notchHub: DiagnosticsReport.NotchHubSnapshot(
                isEnabled: notchHubStore.preferences.isEnabled,
                presentation: notchHubPresentationDescription(notchHubStore.presentation),
                defaultWidgetID: notchHubStore.preferences.defaultWidgetID.rawValue,
                enabledWidgetIDs: notchHubStore.enabledWidgets.map(\.rawValue),
                triggerGesture: notchHubStore.preferences.triggerGesture.rawValue
            ),
            ai: DiagnosticsReport.AISnapshot(
                aiEnabled: aiProviderPreferences.isEnabled,
                transcriptionProvider: aiProviderPreferences.selectedTranscriptionProvider.rawValue,
                transcriptionModel: aiProviderPreferences.transcriptionModel,
                parserProvider: aiProviderPreferences.selectedParserProvider.rawValue,
                parserModel: aiProviderPreferences.parserModel,
                languageMode: aiProviderPreferences.languageMode,
                customParserBaseURLConfigured: !aiProviderPreferences.customParserBaseURL
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .isEmpty
            ),
            screens: screens.map(screenSnapshot)
        )
    }

    func makeJSONString() throws -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(makeReport())
        return String(decoding: data, as: UTF8.self)
    }

    static func defaultFilename(date: Date = .now, calendar: Calendar = .current) -> String {
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return String(
            format: "NotchMove-Diagnostics-%04d%02d%02d-%02d%02d.json",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0,
            components.hour ?? 0,
            components.minute ?? 0
        )
    }

    private func reminderSnapshot() -> DiagnosticsReport.ReminderSnapshot {
        guard let reminderEngine else {
            return DiagnosticsReport.ReminderSnapshot(
                runState: nil,
                presentation: nil,
                manualPause: nil,
                manualPauseUntilDate: nil,
                breakSnoozedUntilDate: nil,
                reminderIntervalSeconds: nil
            )
        }

        return DiagnosticsReport.ReminderSnapshot(
            runState: String(describing: reminderEngine.runState),
            presentation: String(describing: reminderEngine.state.presentation),
            manualPause: reminderEngine.state.manualPause,
            manualPauseUntilDate: reminderEngine.state.manualPauseUntilDate,
            breakSnoozedUntilDate: reminderEngine.state.breakSnoozedUntilDate,
            reminderIntervalSeconds: reminderEngine.reminderInterval
        )
    }

    private func pomodoroSnapshot() -> DiagnosticsReport.PomodoroSnapshot {
        guard let pomodoroEngine else {
            return DiagnosticsReport.PomodoroSnapshot(
                isActive: nil,
                isPaused: nil,
                remainingSeconds: nil,
                phase: nil
            )
        }

        return DiagnosticsReport.PomodoroSnapshot(
            isActive: pomodoroEngine.isActive,
            isPaused: pomodoroEngine.isPaused,
            remainingSeconds: pomodoroEngine.state.remainingSeconds,
            phase: String(describing: pomodoroEngine.state.phase)
        )
    }

    private func screenSnapshot(_ screen: ScreenDescriptor) -> DiagnosticsReport.ScreenSnapshot {
        DiagnosticsReport.ScreenSnapshot(
            displayID: screen.displayID,
            localizedName: screen.localizedName,
            isBuiltIn: screen.isBuiltIn,
            frame: NSStringFromRect(screen.frame),
            hasNotchFrame: screen.notchFrame != nil,
            menuBarHeight: screen.menuBarHeight
        )
    }

    private func overlayDisplayModeDescription(_ mode: Preferences.OverlayDisplayMode) -> String {
        switch mode {
        case .automatic:
            return "automatic"
        case .display(let displayID):
            return "display:\(displayID)"
        }
    }

    private func notchHubPresentationDescription(_ presentation: NotchHubPresentation) -> String {
        switch presentation {
        case .tucked:
            return "tucked"
        case .peek:
            return "peek"
        case .expanded:
            return "expanded"
        case .widget(let widgetID):
            return "widget:\(widgetID.rawValue)"
        case .permissionPrompt(let permission):
            return "permissionPrompt:\(permission.rawValue)"
        case .transientError:
            return "transientError"
        }
    }

    private func microphoneAuthorizationDescription(_ status: AVAuthorizationStatus) -> String {
        switch status {
        case .authorized:
            return "authorized"
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        @unknown default:
            return "unknown"
        }
    }

    private func speechAuthorizationDescription(_ state: AppleSpeechAuthorizationState) -> String {
        switch state {
        case .authorized:
            return "authorized"
        case .notDetermined:
            return "notDetermined"
        case .denied:
            return "denied"
        case .restricted:
            return "restricted"
        case .unknown:
            return "unknown"
        }
    }
}
