//
//  NotchHubProviders.swift
//  NotchMove
//
//  Created by Codex on 6/6/26.
//

import AppKit
import AVFoundation
import EventKit
import Foundation

enum NotchHubActionResult: Equatable {
    case success(String?)
    case failure(String)
}

enum MediaControlCommand: Equatable {
    case playPause
    case next
    case previous
    case openPreferredPlayer
}

enum MediaPlaybackApp: String, CaseIterable, Equatable, Identifiable {
    case music
    case spotify

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .music: "Music"
        case .spotify: "Spotify"
        }
    }

    var bundleIdentifier: String {
        switch self {
        case .music: "com.apple.Music"
        case .spotify: "com.spotify.client"
        }
    }

    var appleScriptName: String {
        switch self {
        case .music: "Music"
        case .spotify: "Spotify"
        }
    }
}

struct MediaPlaybackStatus: Equatable {
    enum PlaybackState: String, Equatable {
        case unavailable
        case stopped
        case playing
        case paused
    }

    var app: MediaPlaybackApp?
    var title: String?
    var artist: String?
    var playbackState: PlaybackState

    init(
        app: MediaPlaybackApp? = nil,
        title: String? = nil,
        artist: String? = nil,
        playbackState: PlaybackState = .unavailable
    ) {
        self.app = app
        self.title = title
        self.artist = artist
        self.playbackState = playbackState
    }

    var displayTitle: String {
        title?.isEmpty == false ? title! : "notch_hub.media.no_track"
    }
}

@MainActor
protocol MediaControlProviding {
    func currentStatus() async -> MediaPlaybackStatus
    func perform(_ command: MediaControlCommand) async -> NotchHubActionResult
}

@MainActor
final class SystemMediaControlProvider: MediaControlProviding {
    func currentStatus() async -> MediaPlaybackStatus {
        for app in MediaPlaybackApp.allCases where isRunning(app) {
            if let status = status(for: app) {
                return status
            }
        }

        return MediaPlaybackStatus()
    }

    func perform(_ command: MediaControlCommand) async -> NotchHubActionResult {
        switch command {
        case .openPreferredPlayer:
            return openPreferredPlayer()
        case .playPause, .next, .previous:
            guard let app = activeApp() ?? MediaPlaybackApp.allCases.first(where: isRunning) else {
                return .failure("No supported media app is running.")
            }

            let appleScriptCommand: String
            switch command {
            case .playPause:
                appleScriptCommand = "playpause"
            case .next:
                appleScriptCommand = "next track"
            case .previous:
                appleScriptCommand = "previous track"
            case .openPreferredPlayer:
                appleScriptCommand = ""
            }

            return runAppleScript(
                """
                tell application "\(app.appleScriptName)"
                    \(appleScriptCommand)
                end tell
                """
            )
        }
    }

    private func activeApp() -> MediaPlaybackApp? {
        MediaPlaybackApp.allCases.first { app in
            guard isRunning(app), let status = status(for: app) else { return false }
            return status.playbackState == .playing
        }
    }

    private func isRunning(_ app: MediaPlaybackApp) -> Bool {
        NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == app.bundleIdentifier }
    }

    private func status(for app: MediaPlaybackApp) -> MediaPlaybackStatus? {
        let source = """
        tell application "\(app.appleScriptName)"
            if it is running then
                set trackName to ""
                set artistName to ""
                set stateName to "stopped"
                try
                    set stateName to (player state as string)
                    set trackName to name of current track
                    set artistName to artist of current track
                end try
                return stateName & linefeed & trackName & linefeed & artistName
            end if
        end tell
        """
        guard case .success(let output) = runAppleScript(source),
              let output,
              !output.isEmpty
        else {
            return MediaPlaybackStatus(app: app, playbackState: .stopped)
        }

        let lines = output.components(separatedBy: .newlines)
        let state = lines.first.map(playbackState(from:)) ?? .stopped
        let title = lines.dropFirst().first?.nilIfEmpty
        let artist = lines.dropFirst(2).first?.nilIfEmpty
        return MediaPlaybackStatus(app: app, title: title, artist: artist, playbackState: state)
    }

    private func openPreferredPlayer() -> NotchHubActionResult {
        let preferredApp: MediaPlaybackApp = .music
        guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: preferredApp.bundleIdentifier) else {
            return .failure("Music is not available on this Mac.")
        }

        NSWorkspace.shared.open(url)
        return .success("Opened Music.")
    }

    private func runAppleScript(_ source: String) -> NotchHubActionResult {
        guard let script = NSAppleScript(source: source) else {
            return .failure("Could not prepare media command.")
        }

        var errorInfo: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorInfo)
        if let errorInfo {
            let message = errorInfo[NSAppleScript.errorMessage] as? String ?? "Apple Events command failed."
            return .failure(message)
        }

        return .success(descriptor.stringValue)
    }

    private func playbackState(from value: String) -> MediaPlaybackStatus.PlaybackState {
        switch value.lowercased() {
        case "playing":
            .playing
        case "paused":
            .paused
        case "stopped":
            .stopped
        default:
            .unavailable
        }
    }
}

struct NotchHubCalendarItem: Identifiable, Equatable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date?
    let source: Source

    enum Source: Equatable {
        case localSchedule
        case calendar
    }
}

@MainActor
protocol CalendarEventProviding {
    func requestAccess() async -> Bool
    func upcomingExternalItems(limit: Int) async -> [NotchHubCalendarItem]
    func localScheduleItems(from items: [DailyScheduleItem]) -> [NotchHubCalendarItem]
}

@MainActor
final class SystemCalendarEventProvider: CalendarEventProviding {
    private let eventStore = EKEventStore()

    func requestAccess() async -> Bool {
        if #available(macOS 14.0, *) {
            return await withCheckedContinuation { continuation in
                eventStore.requestFullAccessToEvents { granted, _ in
                    continuation.resume(returning: granted)
                }
            }
        }

        return await withCheckedContinuation { continuation in
            eventStore.requestAccess(to: .event) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func upcomingExternalItems(limit: Int) async -> [NotchHubCalendarItem] {
        guard isAuthorized else { return [] }
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .day, value: 1, to: now) ?? now.addingTimeInterval(24 * 60 * 60)
        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endDate,
            calendars: nil
        )
        return eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .prefix(limit)
            .map {
                NotchHubCalendarItem(
                    id: "event.\($0.eventIdentifier ?? $0.calendarItemIdentifier ?? UUID().uuidString)",
                    title: $0.title ?? "Calendar Event",
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    source: .calendar
                )
            }
    }

    func localScheduleItems(from items: [DailyScheduleItem]) -> [NotchHubCalendarItem] {
        let now = Date()
        return items
            .filter { $0.isReminderEnabled && ($0.endDate ?? $0.startDate) >= now }
            .sorted { $0.startDate < $1.startDate }
            .prefix(4)
            .map {
                NotchHubCalendarItem(
                    id: "local.\($0.id.uuidString)",
                    title: $0.title,
                    startDate: $0.startDate,
                    endDate: $0.endDate,
                    source: .localSchedule
                )
            }
    }

    private var isAuthorized: Bool {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(macOS 14.0, *) {
            return status == .fullAccess
        }

        return status == .authorized
    }
}

@MainActor
protocol ShortcutRunning {
    func runShortcut(named name: String) async -> NotchHubActionResult
}

@MainActor
final class SystemShortcutRunner: ShortcutRunning {
    func runShortcut(named name: String) async -> NotchHubActionResult {
        guard var components = URLComponents(string: "shortcuts://run-shortcut") else {
            return .failure("Could not create Shortcuts URL.")
        }
        components.queryItems = [
            URLQueryItem(name: "name", value: name)
        ]
        guard let url = components.url else {
            return .failure("Shortcut name is not valid.")
        }

        NSWorkspace.shared.open(url)
        return .success("Running shortcut.")
    }
}

@MainActor
protocol CameraPermissionProviding {
    var authorizationStatus: AVAuthorizationStatus { get }
    func requestAccess() async -> Bool
}

@MainActor
final class SystemCameraPermissionProvider: CameraPermissionProviding {
    var authorizationStatus: AVAuthorizationStatus {
        AVCaptureDevice.authorizationStatus(for: .video)
    }

    func requestAccess() async -> Bool {
        await withCheckedContinuation { continuation in
            AVCaptureDevice.requestAccess(for: .video) { granted in
                continuation.resume(returning: granted)
            }
        }
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
