//
//  DailyScheduleStore.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation
import Observation

@MainActor
@Observable
final class DailyScheduleStore {
    private enum Keys {
        static let items = "dailyScheduleItems"
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private let calendar: Calendar
    private let dateProvider: @Sendable () -> Date

    private(set) var items: [DailyScheduleItem] {
        didSet {
            guard items != oldValue else { return }
            save()
        }
    }

    init(
        defaults: UserDefaults = .standard,
        storageKey: String = Keys.items,
        calendar: Calendar = .current,
        dateProvider: @escaping @Sendable () -> Date = { .now }
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.calendar = calendar
        self.dateProvider = dateProvider
        self.items = Self.loadItems(from: defaults, key: storageKey)
    }

    @discardableResult
    func add(_ item: DailyScheduleItem) -> DailyScheduleItem {
        items.append(item)
        sortItems()
        return item
    }

    @discardableResult
    func add(
        title: String,
        startDate: Date,
        endDate: Date? = nil,
        notes: String? = nil,
        reminderLeadMinutes: Int = 10,
        isReminderEnabled: Bool = true
    ) -> DailyScheduleItem {
        add(DailyScheduleItem(
            title: title,
            startDate: startDate,
            endDate: endDate,
            notes: notes,
            reminderLeadMinutes: reminderLeadMinutes,
            isReminderEnabled: isReminderEnabled
        ))
    }

    func update(_ item: DailyScheduleItem) {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        items[index] = item
        sortItems()
    }

    func delete(_ id: DailyScheduleItem.ID) {
        items.removeAll { $0.id == id }
    }

    func replaceImportedItems(_ importedItems: [DailyScheduleItem], referenceDate: Date? = nil) {
        let date = referenceDate ?? dateProvider()
        let importedToday = importedItems.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
        let preservedItems = items.filter { !calendar.isDate($0.startDate, inSameDayAs: date) }
        items = (preservedItems + importedToday).sorted { $0.startDate < $1.startDate }
    }

    func itemsForToday(referenceDate: Date? = nil) -> [DailyScheduleItem] {
        let date = referenceDate ?? dateProvider()
        return items
            .filter { calendar.isDate($0.startDate, inSameDayAs: date) }
            .sorted { $0.startDate < $1.startDate }
    }

    func markReminded(_ id: DailyScheduleItem.ID, at date: Date? = nil) {
        guard let index = items.firstIndex(where: { $0.id == id }) else { return }
        items[index].lastRemindedDate = date ?? dateProvider()
    }

    func clearToday(referenceDate: Date? = nil) {
        let date = referenceDate ?? dateProvider()
        items.removeAll { calendar.isDate($0.startDate, inSameDayAs: date) }
    }

    private func sortItems() {
        items.sort { $0.startDate < $1.startDate }
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func loadItems(from defaults: UserDefaults, key: String) -> [DailyScheduleItem] {
        guard let data = defaults.data(forKey: key),
              let items = try? JSONDecoder().decode([DailyScheduleItem].self, from: data)
        else {
            return []
        }

        return items.sorted { $0.startDate < $1.startDate }
    }
}
