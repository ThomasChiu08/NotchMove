//
//  SettingsObserver.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/17/26.
//

import Foundation
import OSLog

/// Bridges UserDefaults changes to runtime components.
///
/// Listens for `UserDefaults.didChangeNotification` and pushes relevant
/// values into `ReminderScheduler` and `NotchViewModel` so changes from
/// the Settings UI take effect immediately. A 0.3 s debounce coalesces
/// rapid-fire notifications from multiple @AppStorage writes.
@MainActor
final class SettingsObserver {
    private weak var scheduler: ReminderScheduler?
    private weak var viewModel: NotchViewModel?
    private weak var windowController: NotchWindowController?
    private var observation: NSObjectProtocol?
    private var scheduleCheckTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "settings")

    init(
        scheduler: ReminderScheduler,
        viewModel: NotchViewModel,
        windowController: NotchWindowController
    ) {
        self.scheduler = scheduler
        self.viewModel = viewModel
        self.windowController = windowController

        applyCurrentSettings()
        startScheduleCheck()

        observation = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.debouncedApply() }
        }
    }

    func tearDown() {
        if let observation { NotificationCenter.default.removeObserver(observation) }
        observation = nil
        scheduleCheckTask?.cancel()
        scheduleCheckTask = nil
        debounceTask?.cancel()
        debounceTask = nil
    }

    // MARK: - Debounced Apply

    private func debouncedApply() {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            applyCurrentSettings()
        }
    }

    // MARK: - Apply Settings

    private func applyCurrentSettings() {
        let defaults = UserDefaults.standard

        // Reminder interval
        let minutes = defaults.integer(forKey: "reminderIntervalMinutes")
        if minutes > 0 {
            scheduler?.reminderInterval = TimeInterval(minutes) * 60
        }

        // Sit-aware idle threshold
        let sitAware = defaults.bool(forKey: "sitAwareEnabled")
        scheduler?.idleResetThreshold = sitAware ? 180 : .greatestFiniteMagnitude

        // Auto-dismiss
        let autoDismissEnabled = defaults.bool(forKey: "autoDismissEnabled")
        let autoDismissSeconds = defaults.integer(forKey: "autoDismissSeconds")
        viewModel?.autoDismissEnabled = autoDismissEnabled
        if autoDismissSeconds > 0 {
            viewModel?.reminderDuration = TimeInterval(autoDismissSeconds)
        }

        // Behavior flags
        viewModel?.hoverPreviewEnabled = defaults.bool(forKey: "hoverPreviewEnabled")
        windowController?.notchExpansionEnabled = defaults.bool(forKey: "notchExpansionEnabled")

        logger.notice("Settings applied — interval=\(minutes)m, sitAware=\(sitAware), autoDismiss=\(autoDismissEnabled)")
    }

    // MARK: - Work-Hours Schedule

    private func startScheduleCheck() {
        scheduleCheckTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.evaluateSchedule()
                try? await Task.sleep(for: .seconds(60))
            }
        }
    }

    private func evaluateSchedule() {
        let defaults = UserDefaults.standard
        guard defaults.bool(forKey: "scheduleEnabled") else { return }

        let cal = Calendar.current
        let now = Date.now
        let comps = cal.dateComponents([.hour, .minute, .weekday], from: now)
        guard let hour = comps.hour, let minute = comps.minute, let weekday = comps.weekday else { return }

        // Check weekday (Sun=1, Sat=7)
        if defaults.bool(forKey: "weekdaysOnly") {
            let isWeekend = weekday == 1 || weekday == 7
            if isWeekend {
                scheduler?.isEnabled = false
                return
            }
        }

        let startHour = defaults.integer(forKey: "scheduleStartHour")
        let startMinute = defaults.integer(forKey: "scheduleStartMinute")
        let endHour = defaults.integer(forKey: "scheduleEndHour")
        let endMinute = defaults.integer(forKey: "scheduleEndMinute")

        let currentMinutes = hour * 60 + minute
        let startMinutes = startHour * 60 + startMinute
        let endMinutes = endHour * 60 + endMinute

        let withinSchedule = currentMinutes >= startMinutes && currentMinutes < endMinutes
        scheduler?.isEnabled = withinSchedule
    }
}
