//
//  Preferences.swift
//  NotchMove
//
//  Created by Codex on 4/22/26.
//

import CoreGraphics
import Foundation

struct Preferences: Equatable {
    enum OverlayDisplayMode: Equatable, Hashable {
        case automatic
        case display(CGDirectDisplayID)
    }

    struct Schedule: Equatable {
        var isEnabled: Bool
        var startHour: Int
        var startMinute: Int
        var endHour: Int
        var endMinute: Int
        var weekdaysOnly: Bool

        var hasValidTimeRange: Bool {
            (startHour * 60 + startMinute) < (endHour * 60 + endMinute)
        }
    }

    var soundEnabled: Bool
    var reminderIntervalMinutes: Int
    var sitAwareEnabled: Bool
    var schedule: Schedule
    var notchExpansionEnabled: Bool
    var hoverPreviewEnabled: Bool
    var autoDismissEnabled: Bool
    var autoDismissSeconds: Int
    var appLanguage: String
    var overlayDisplayMode: OverlayDisplayMode

    static let defaults = Preferences(
        soundEnabled: true,
        reminderIntervalMinutes: 30,
        sitAwareEnabled: true,
        schedule: Schedule(
            isEnabled: false,
            startHour: 9,
            startMinute: 0,
            endHour: 18,
            endMinute: 0,
            weekdaysOnly: true
        ),
        notchExpansionEnabled: true,
        hoverPreviewEnabled: true,
        autoDismissEnabled: true,
        autoDismissSeconds: 60,
        appLanguage: "en",
        overlayDisplayMode: .automatic
    )
}
