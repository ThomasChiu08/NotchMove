//
//  SettingsView.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/17/26.
//

import SwiftUI

struct SettingsView: View {
    // MARK: - Reminders

    @AppStorage("reminderIntervalMinutes") private var intervalMinutes = 30
    @AppStorage("sitAwareEnabled") private var sitAwareEnabled = true

    // MARK: - Schedule

    @AppStorage("scheduleEnabled") private var scheduleEnabled = false
    @AppStorage("scheduleStartHour") private var startHour = 9
    @AppStorage("scheduleStartMinute") private var startMinute = 0
    @AppStorage("scheduleEndHour") private var endHour = 18
    @AppStorage("scheduleEndMinute") private var endMinute = 0
    @AppStorage("weekdaysOnly") private var weekdaysOnly = true

    // MARK: - Behavior

    @AppStorage("notchExpansionEnabled") private var notchExpansionEnabled = true
    @AppStorage("hoverPreviewEnabled") private var hoverPreviewEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("autoDismissEnabled") private var autoDismissEnabled = true
    @AppStorage("autoDismissSeconds") private var autoDismissSeconds = 60

    // MARK: - Stats

    @State private var todayBreaks = 0
    @State private var weekBreaks = 0
    @State private var showingResetConfirmation = false

    private static let intervalOptions = [15, 20, 25, 30, 45, 60]
    private static let dismissOptions = [30, 45, 60, 90, 120]

    var body: some View {
        Form {
            remindersSection
            scheduleSection
            behaviorSection
            statisticsSection
            aboutSection
        }
        .formStyle(.grouped)
        .frame(minWidth: 420, minHeight: 520)
        .onAppear { refreshStats() }
    }

    // MARK: - Reminders

    private var remindersSection: some View {
        Section {
            Picker("Remind me every", selection: $intervalMinutes) {
                ForEach(Self.intervalOptions, id: \.self) { minutes in
                    Text("\(minutes) minutes").tag(minutes)
                }
            }

            Toggle("Sit-aware mode", isOn: $sitAwareEnabled)
        } header: {
            Text("Reminders")
        } footer: {
            if sitAwareEnabled {
                Text("Resets the timer when you've been idle for 3+ minutes — you probably already stood up.")
            } else {
                Text("Longer intervals reduce interruptions but may allow more continuous sitting.")
            }
        }
    }

    // MARK: - Schedule

    private var scheduleSection: some View {
        Section {
            Toggle("Active during work hours only", isOn: $scheduleEnabled)

            if scheduleEnabled {
                DatePicker("From", selection: startTimeBinding, displayedComponents: .hourAndMinute)
                DatePicker("To", selection: endTimeBinding, displayedComponents: .hourAndMinute)
                Toggle("Weekdays only", isOn: $weekdaysOnly)
            }
        } header: {
            Text("Schedule")
        } footer: {
            if scheduleEnabled && !isValidTimeRange {
                Text("End time should be after start time.")
                    .foregroundStyle(.red)
            } else if scheduleEnabled {
                Text("Reminders are paused outside these hours.")
            }
        }
    }

    // MARK: - Behavior

    private var behaviorSection: some View {
        Section {
            Toggle("Expand notch on reminder", isOn: $notchExpansionEnabled)
            Toggle("Show hover preview", isOn: $hoverPreviewEnabled)
            Toggle("Play sound on reminder", isOn: $soundEnabled)

            Toggle("Auto-dismiss reminder", isOn: $autoDismissEnabled)
            if autoDismissEnabled {
                Picker("Dismiss after", selection: $autoDismissSeconds) {
                    ForEach(Self.dismissOptions, id: \.self) { seconds in
                        Text("\(seconds) seconds").tag(seconds)
                    }
                }
            }
        } header: {
            Text("Behavior")
        } footer: {
            Text("Controls how reminders appear and disappear.")
        }
    }

    // MARK: - Statistics

    private var statisticsSection: some View {
        Section {
            LabeledContent("Breaks today", value: "\(todayBreaks)")
            LabeledContent("Breaks this week", value: "\(weekBreaks)")

            HStack {
                Button("Reset Statistics", role: .destructive) {
                    showingResetConfirmation = true
                }
                .confirmationDialog(
                    "Reset all statistics?",
                    isPresented: $showingResetConfirmation,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) { resetStatistics() }
                    Button("Cancel", role: .cancel) {}
                }

                Spacer()

                Button("Restore Defaults") {
                    restoreDefaults()
                }
            }
        } header: {
            Text("Statistics")
        }
    }

    // MARK: - About

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: appVersion)

            Text("NotchMove helps you break long sitting periods with elegant notch reminders. Stand up, stretch, move.")
                .font(.callout)
                .foregroundStyle(.secondary)
        } header: {
            Text("About")
        }
    }

    // MARK: - Date Bindings

    private var startTimeBinding: Binding<Date> {
        Binding(
            get: { dateFrom(hour: startHour, minute: startMinute) },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                startHour = comps.hour ?? 9
                startMinute = comps.minute ?? 0
            }
        )
    }

    private var endTimeBinding: Binding<Date> {
        Binding(
            get: { dateFrom(hour: endHour, minute: endMinute) },
            set: { newDate in
                let comps = Calendar.current.dateComponents([.hour, .minute], from: newDate)
                endHour = comps.hour ?? 18
                endMinute = comps.minute ?? 0
            }
        )
    }

    private func dateFrom(hour: Int, minute: Int) -> Date {
        Calendar.current.date(from: DateComponents(hour: hour, minute: minute)) ?? .now
    }

    private var isValidTimeRange: Bool {
        (startHour * 60 + startMinute) < (endHour * 60 + endMinute)
    }

    // MARK: - Stats Helpers

    private func refreshStats() {
        let defaults = UserDefaults.standard
        todayBreaks = defaults.integer(forKey: todayBreaksKey)
        weekBreaks = defaults.integer(forKey: weekBreaksKey)
    }

    private func resetStatistics() {
        let defaults = UserDefaults.standard
        defaults.set(0, forKey: todayBreaksKey)
        defaults.set(0, forKey: weekBreaksKey)
        refreshStats()
    }

    private func restoreDefaults() {
        intervalMinutes = 30
        sitAwareEnabled = true
        scheduleEnabled = false
        startHour = 9
        startMinute = 0
        endHour = 18
        endMinute = 0
        weekdaysOnly = true
        notchExpansionEnabled = true
        hoverPreviewEnabled = true
        soundEnabled = true
        autoDismissEnabled = true
        autoDismissSeconds = 60
    }

    /// Mirrors the key format from `SessionCounter`.
    private var todayBreaksKey: String {
        let cal = Calendar.current
        let now = Date.now
        let y = cal.component(.year, from: now)
        let m = cal.component(.month, from: now)
        let d = cal.component(.day, from: now)
        return String(format: "breaks_%04d-%02d-%02d", y, m, d)
    }

    private var weekBreaksKey: String {
        let cal = Calendar.current
        let week = cal.component(.weekOfYear, from: .now)
        let year = cal.component(.yearForWeekOfYear, from: .now)
        return String(format: "breaksWeek_%04d-W%02d", year, week)
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }
}

#Preview {
    SettingsView()
        .frame(width: 420, height: 560)
}
