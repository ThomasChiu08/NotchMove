//
//  NotchViewModel.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import Foundation

@Observable
final class NotchViewModel {
    enum State: Equatable {
        case dormant
        case hovering
        case reminding
        case dismissed
    }

    private(set) var state: State = .dormant
    private(set) var reminderStartDate: Date = .distantPast

    let reminderDuration: TimeInterval = 30
    var topInset: CGFloat = 38

    /// Called when the reminder cycle completes (dismissed → dormant).
    /// Used by AppDelegate to resume the ReminderScheduler.
    var onReminderCompleted: (() -> Void)?

    private var autoDismissTask: Task<Void, Never>?

    var isExpanded: Bool {
        state == .hovering || state == .reminding
    }

    func hover() {
        guard state == .dormant else { return }
        state = .hovering
    }

    func unhover() {
        guard state == .hovering else { return }
        state = .dormant
    }

    func triggerReminder() {
        autoDismissTask?.cancel()
        reminderStartDate = .now
        state = .reminding

        autoDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(30))
            guard !Task.isCancelled else { return }
            self?.dismiss()
        }
    }

    func dismiss() {
        autoDismissTask?.cancel()
        autoDismissTask = nil
        state = .dismissed

        Task { [weak self] in
            try? await Task.sleep(for: .seconds(0.4))
            guard !Task.isCancelled else { return }
            self?.state = .dormant
            self?.onReminderCompleted?()
        }
    }
}
