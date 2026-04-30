//
//  DailyScheduleDashboardView.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Combine
import SwiftUI

struct TodayDashboardView: View {
    let languageManager: LanguageManager
    @Bindable var scheduleStore: DailyScheduleStore
    @Bindable var preferencesStore: PreferencesStore
    @Bindable var breakStatsStore: BreakStatsStore
    let reminderEngine: ReminderEngine

    @State private var showingAddSheet = false
    @State private var now = Date()

    var body: some View {
        VStack(spacing: 0) {
            DashboardPageHeader(
                titleKey: "dashboard.page.today",
                systemImage: "sun.max",
                metaText: todayMetaText
            ) {
                Button {
                    reminderEngine.send(.manualTrigger)
                } label: {
                    Label("menu.remind_now", systemImage: "bell")
                }
                .buttonStyle(.bordered)

                Button {
                    showingAddSheet = true
                } label: {
                    Label("dashboard.add.button", systemImage: "plus")
                }
                .buttonStyle(.bordered)
            }

            Divider()

            DashboardDocumentPage {
                rhythmSection
                timelineSection
            }
        }
        .sheet(isPresented: $showingAddSheet) {
            DailyScheduleItemEditorSheet(languageManager: languageManager) { item in
                scheduleStore.add(item)
            }
            .environment(\.locale, languageManager.locale)
        }
        .onAppear {
            breakStatsStore.refresh()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            now = date
            breakStatsStore.refresh()
        }
    }

    private var rhythmSection: some View {
        DashboardSectionBlock("dashboard.today.rhythm") {
            DashboardValueRow(
                "dashboard.property.tracking_status",
                value: runStateText
            )
            DashboardValueRow(
                "dashboard.property.next_stand_reminder",
                value: nextStandReminderText
            )
            DashboardValueRow(
                "dashboard.property.current_schedule",
                value: scheduleSummary(for: currentItem, emptyKey: "dashboard.none_current")
            )
            DashboardValueRow(
                "dashboard.property.next_schedule",
                value: scheduleSummary(for: nextItem, emptyKey: "dashboard.none_next")
            )
            DashboardValueRow(
                "breaks_today",
                value: String(breakStatsStore.todayBreaks)
            )
        }
    }

    @ViewBuilder
    private var timelineSection: some View {
        DashboardSectionBlock("dashboard.timeline.title") {
            if todayItems.isEmpty {
                DashboardEmptyInline(descriptionKey: "dashboard.empty.description") {
                    Button {
                        showingAddSheet = true
                    } label: {
                        Label("dashboard.add.schedule_item", systemImage: "plus")
                    }
                    .buttonStyle(.bordered)
                }
            } else {
                ForEach(todayItems) { item in
                    ScheduleTimelineRow(
                        item: item,
                        now: now,
                        languageManager: languageManager
                    )
                }
            }
        }
    }

    private var todayItems: [DailyScheduleItem] {
        scheduleStore.itemsForToday(referenceDate: now)
    }

    private var currentItem: DailyScheduleItem? {
        todayItems.first { item in
            let fallbackEndDate = item.startDate.addingTimeInterval(60 * 60)
            return item.startDate <= now && (item.endDate ?? fallbackEndDate) >= now
        }
    }

    private var nextItem: DailyScheduleItem? {
        todayItems.first { $0.startDate > now }
    }

    private var todayMetaText: String {
        String(
            format: localizedString("dashboard.today.meta_format"),
            nextStandReminderText,
            breakStatsStore.todayBreaks,
            runStateText
        )
    }

    private var runStateText: String {
        localizedString(runStateKey)
    }

    private var runStateKey: String {
        switch reminderEngine.runState {
        case .tracking:
            "dashboard.run_state.tracking"
        case .manuallyPaused:
            "dashboard.run_state.paused"
        case .scheduleBlocked:
            "dashboard.run_state.schedule_blocked"
        case .presentingReminder:
            "dashboard.run_state.reminding"
        case .idleSuppressed:
            "dashboard.run_state.idle"
        }
    }

    private var nextStandReminderText: String {
        switch reminderEngine.runState {
        case .tracking:
            let minutes = reminderEngine.minutesRemaining
            if minutes <= 1 {
                return localizedString("dashboard.next_stand_soon")
            }

            return String(
                format: localizedString("dashboard.next_stand_minutes_format"),
                minutes
            )
        case .presentingReminder:
            return localizedString("dashboard.run_state.reminding")
        case .manuallyPaused:
            return localizedString("dashboard.run_state.paused")
        case .scheduleBlocked:
            return localizedString("dashboard.run_state.schedule_blocked")
        case .idleSuppressed:
            return localizedString("dashboard.run_state.idle")
        }
    }

    private func scheduleSummary(for item: DailyScheduleItem?, emptyKey: String) -> String {
        guard let item else { return localizedString(emptyKey) }
        return String(
            format: localizedString("dashboard.schedule.summary_format"),
            item.title,
            timeRange(for: item)
        )
    }

    private func timeRange(for item: DailyScheduleItem) -> String {
        DailyScheduleText.timeRange(for: item, languageManager: languageManager)
    }

    private func localizedString(_ key: String) -> String {
        languageManager.localizedString(key)
    }
}

struct DailyScheduleDashboardView: View {
    let languageManager: LanguageManager
    @Bindable var scheduleStore: DailyScheduleStore

    @State private var selectedItemID: DailyScheduleItem.ID?
    @State private var showingAddSheet = false
    @State private var showingImportSheet = false
    @State private var showingClearConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var pendingDeleteItem: DailyScheduleItem?
    @State private var editingItem: DailyScheduleItem?
    @State private var now = Date()

    var body: some View {
        VStack(spacing: 0) {
            DashboardPageHeader(
                titleKey: "dashboard.page.schedule",
                systemImage: "calendar",
                metaText: scheduleMetaText
            ) {
                Button {
                    showingAddSheet = true
                } label: {
                    Label("dashboard.add.button", systemImage: "plus")
                }
                .buttonStyle(.bordered)

                Button {
                    showingImportSheet = true
                } label: {
                    Label("dashboard.import.button", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.bordered)

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("dashboard.clear.button", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .disabled(todayItems.isEmpty)
            }

            Divider()

            content
        }
        .sheet(isPresented: $showingAddSheet) {
            DailyScheduleItemEditorSheet(languageManager: languageManager) { item in
                let addedItem = scheduleStore.add(item)
                selectedItemID = addedItem.id
            }
            .environment(\.locale, languageManager.locale)
        }
        .sheet(item: $editingItem) { item in
            DailyScheduleItemEditorSheet(
                languageManager: languageManager,
                item: item
            ) { updatedItem in
                scheduleStore.update(updatedItem)
                selectedItemID = updatedItem.id
            }
            .environment(\.locale, languageManager.locale)
        }
        .sheet(isPresented: $showingImportSheet) {
            DailyScheduleImportSheet(languageManager: languageManager) { importedItems in
                scheduleStore.replaceImportedItems(importedItems)
                ensureSelection()
            }
            .environment(\.locale, languageManager.locale)
        }
        .confirmationDialog(
            Text("dashboard.clear.confirm_title"),
            isPresented: $showingClearConfirmation,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                scheduleStore.clearToday()
                selectedItemID = nil
            } label: {
                Text("dashboard.clear.action")
            }
            Button(role: .cancel) {} label: {
                Text("cancel")
            }
        }
        .confirmationDialog(
            Text("dashboard.delete.confirm_title"),
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button(role: .destructive) {
                if let pendingDeleteItem {
                    scheduleStore.delete(pendingDeleteItem.id)
                }
                self.pendingDeleteItem = nil
                ensureSelection()
            } label: {
                Text("dashboard.delete.action")
            }
            Button(role: .cancel) {
                pendingDeleteItem = nil
            } label: {
                Text("cancel")
            }
        }
        .onAppear {
            ensureSelection()
        }
        .onChange(of: todayItems.map(\.id)) { _, _ in
            ensureSelection()
        }
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { date in
            now = date
        }
    }

    @ViewBuilder
    private var content: some View {
        DashboardDocumentPage {
            DashboardSectionBlock("dashboard.schedule.items") {
                if todayItems.isEmpty {
                    DashboardEmptyInline(descriptionKey: "dashboard.empty.description") {
                        Button {
                            showingAddSheet = true
                        } label: {
                            Label("dashboard.add.schedule_item", systemImage: "plus")
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    ForEach(todayItems) { item in
                        ScheduleEditorRow(
                            item: item,
                            now: now,
                            isSelected: item.id == selectedItemID,
                            isReminderEnabled: reminderEnabledBinding(for: item),
                            languageManager: languageManager
                        ) {
                            selectedItemID = item.id
                        } onEdit: {
                            editingItem = item
                        } onDelete: {
                            requestDelete(item)
                        }
                    }
                }
            }

            if let selectedItem {
                DashboardSectionBlock("dashboard.properties.title") {
                    DailyScheduleDetailPropertiesView(
                        item: selectedItem,
                        scheduleStore: scheduleStore,
                        languageManager: languageManager
                    ) {
                        editingItem = selectedItem
                    } onDelete: {
                        requestDelete(selectedItem)
                    }
                }
            }
        }
    }

    private var scheduleMetaText: String {
        String(
            format: languageManager.localizedString("dashboard.schedule.meta_format"),
            todayItems.count
        )
    }

    private var todayItems: [DailyScheduleItem] {
        scheduleStore.itemsForToday(referenceDate: now)
    }

    private var selectedItem: DailyScheduleItem? {
        guard let selectedItemID else { return nil }
        return todayItems.first { $0.id == selectedItemID }
    }

    private func reminderEnabledBinding(for item: DailyScheduleItem) -> Binding<Bool> {
        Binding(
            get: {
                scheduleStore.items.first { $0.id == item.id }?.isReminderEnabled ?? item.isReminderEnabled
            },
            set: { isEnabled in
                var updatedItem = item
                updatedItem.isReminderEnabled = isEnabled
                scheduleStore.update(updatedItem)
            }
        )
    }

    private func requestDelete(_ item: DailyScheduleItem) {
        pendingDeleteItem = item
        showingDeleteConfirmation = true
    }

    private func ensureSelection() {
        if let selectedItemID, todayItems.contains(where: { $0.id == selectedItemID }) {
            return
        }

        selectedItemID = todayItems.first?.id
    }
}

struct BreaksDashboardView: View {
    let languageManager: LanguageManager
    @Bindable var breakStatsStore: BreakStatsStore

    @State private var showingResetConfirmation = false
    @State private var now = Date()

    var body: some View {
        VStack(spacing: 0) {
            DashboardPageHeader(
                titleKey: "dashboard.page.breaks",
                systemImage: "figure.stand",
                metaText: breaksMetaText
            )

            Divider()

            DashboardDocumentPage {
                DashboardSectionBlock("dashboard.breaks.today") {
                    DashboardValueRow("breaks_today", value: String(breakStatsStore.todayBreaks))
                    DashboardValueRow("breaks_this_week", value: String(breakStatsStore.weekBreaks))
                }

                DashboardSectionBlock("dashboard.breaks.weekly_progress") {
                    WeeklyBreakStrip(
                        summaries: breakStatsStore.weekBreaksByDay(referenceDate: now)
                    )
                }

                DashboardSectionBlock("dashboard.breaks.records") {
                    DashboardEmptyInline(descriptionKey: "dashboard.breaks.records_description") {
                        EmptyView()
                    }
                }

                DashboardSectionBlock("dashboard.danger_zone") {
                    HStack {
                        Button(role: .destructive) {
                            showingResetConfirmation = true
                        } label: {
                            Text("reset_statistics")
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }
                    .padding(.vertical, 8)
                }
            }
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
        .onAppear {
            breakStatsStore.refresh()
        }
        .onReceive(Timer.publish(every: 60, on: .main, in: .common).autoconnect()) { date in
            now = date
            breakStatsStore.refresh()
        }
    }

    private var breaksMetaText: String {
        String(
            format: languageManager.localizedString("dashboard.breaks.meta_format"),
            breakStatsStore.todayBreaks,
            breakStatsStore.weekBreaks
        )
    }
}

private struct ScheduleTimelineRow: View {
    let item: DailyScheduleItem
    let now: Date
    let languageManager: LanguageManager

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(DailyScheduleText.timeRange(for: item, languageManager: languageManager))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 104, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)

                    Text(LocalizedStringKey(statusKey))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(.quaternary, in: RoundedRectangle(cornerRadius: 6))
                }

                HStack(spacing: 8) {
                    Text(reminderText)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let notes = item.notes, !notes.isEmpty {
                        Text(notes)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: 1)
        }
    }

    private var reminderText: String {
        if item.isReminderEnabled {
            return String(
                format: languageManager.localizedString("dashboard.row.lead_minutes_format"),
                item.reminderLeadMinutes
            )
        }

        return languageManager.localizedString("dashboard.row.no_alert")
    }

    private var statusKey: String {
        let fallbackEndDate = item.startDate.addingTimeInterval(60 * 60)
        let endDate = item.endDate ?? fallbackEndDate

        if now < item.startDate {
            return "dashboard.schedule.status.upcoming"
        }

        if now <= endDate {
            return "dashboard.schedule.status.active"
        }

        return "dashboard.schedule.status.done"
    }
}

private struct ScheduleEditorRow: View {
    let item: DailyScheduleItem
    let now: Date
    let isSelected: Bool
    @Binding var isReminderEnabled: Bool
    let languageManager: LanguageManager
    let onSelect: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Text(DailyScheduleText.timeRange(for: item, languageManager: languageManager))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 104, alignment: .leading)

            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(LocalizedStringKey(statusKey))
                        .foregroundStyle(.secondary)

                    Text(reminderText)
                        .foregroundStyle(.secondary)

                    if let notes = item.notes, !notes.isEmpty {
                        Text(notes)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                .font(.caption)
            }

            Spacer(minLength: 12)

            Toggle("dashboard.field.reminder_enabled", isOn: $isReminderEnabled)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)

            HStack(spacing: 4) {
                Button(action: onEdit) {
                    Image(systemName: "pencil")
                }
                .help(Text("dashboard.edit.button"))

                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                }
                .help(Text("dashboard.delete.button"))
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .opacity(isHovering || isSelected ? 1 : 0)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 9)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 7))
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .onHover { hovering in
            isHovering = hovering
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(.separator)
                .frame(height: isSelected ? 0 : 1)
        }
    }

    private var rowBackground: Color {
        if isSelected {
            return Color.secondary.opacity(0.12)
        }

        if isHovering {
            return Color.secondary.opacity(0.08)
        }

        return .clear
    }

    private var reminderText: String {
        if item.isReminderEnabled {
            return String(
                format: languageManager.localizedString("dashboard.row.lead_minutes_format"),
                item.reminderLeadMinutes
            )
        }

        return languageManager.localizedString("dashboard.row.no_alert")
    }

    private var statusKey: String {
        let fallbackEndDate = item.startDate.addingTimeInterval(60 * 60)
        let endDate = item.endDate ?? fallbackEndDate

        if now < item.startDate {
            return "dashboard.schedule.status.upcoming"
        }

        if now <= endDate {
            return "dashboard.schedule.status.active"
        }

        return "dashboard.schedule.status.done"
    }
}

private struct DailyScheduleDetailPropertiesView: View {
    let item: DailyScheduleItem
    let scheduleStore: DailyScheduleStore
    let languageManager: LanguageManager
    let onEdit: () -> Void
    let onDelete: () -> Void

    var body: some View {
        DashboardValueRow("dashboard.field.title", value: item.title)

        DashboardValueRow(
            "dashboard.field.time",
            value: DailyScheduleText.timeRange(for: item, languageManager: languageManager)
        )

        DashboardPropertyRow("dashboard.field.reminder_enabled") {
            Toggle("dashboard.field.reminder_enabled", isOn: reminderEnabledBinding)
                .labelsHidden()
                .toggleStyle(.switch)
                .controlSize(.small)
        }

        DashboardPropertyRow("dashboard.field.lead_time") {
            Stepper(value: reminderLeadMinutesBinding, in: 0...120, step: 5) {
                Text(String(
                    format: languageManager.localizedString("dashboard.field.lead_minutes_format"),
                    item.reminderLeadMinutes
                ))
            }
            .controlSize(.small)
        }

        if let reminderStatusText {
            DashboardValueRow("dashboard.field.reminder_status", value: reminderStatusText)
        }

        DashboardValueRow(
            "dashboard.field.notes",
            value: item.notes?.isEmpty == false ? item.notes ?? "" : languageManager.localizedString("dashboard.none")
        )

        HStack(spacing: 8) {
            Button {
                onEdit()
            } label: {
                Label("dashboard.edit.button", systemImage: "pencil")
            }
            .buttonStyle(.bordered)

            Button(role: .destructive) {
                onDelete()
            } label: {
                Label("dashboard.delete.button", systemImage: "trash")
            }
            .buttonStyle(.bordered)
        }
        .controlSize(.small)
        .padding(.top, 8)
    }

    private var reminderEnabledBinding: Binding<Bool> {
        Binding(
            get: { item.isReminderEnabled },
            set: { isEnabled in
                updateItem { $0.isReminderEnabled = isEnabled }
            }
        )
    }

    private var reminderLeadMinutesBinding: Binding<Int> {
        Binding(
            get: { item.reminderLeadMinutes },
            set: { minutes in
                updateItem { $0.reminderLeadMinutes = minutes }
            }
        )
    }

    private var reminderStatusText: String? {
        if item.hasRemindedToday {
            return languageManager.localizedString("dashboard.status.reminded")
        }

        if let snoozedUntilDate = item.snoozedUntilDate, snoozedUntilDate > .now {
            return String(
                format: languageManager.localizedString("dashboard.status.snoozed_until_format"),
                snoozedUntilDate.formatted(date: .omitted, time: .shortened)
            )
        }

        return nil
    }

    private func updateItem(_ update: (inout DailyScheduleItem) -> Void) {
        var updatedItem = item
        update(&updatedItem)
        scheduleStore.update(updatedItem)
    }
}

private struct WeeklyBreakStrip: View {
    let summaries: [BreakDaySummary]

    private var maximumCount: Int {
        max(summaries.map(\.count).max() ?? 0, 1)
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(summaries) { summary in
                VStack(spacing: 6) {
                    Text(summary.date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(summary.count > 0 ? Color.green.opacity(0.62) : Color.secondary.opacity(0.16))
                        .frame(height: barHeight(for: summary.count))
                        .frame(maxHeight: 34, alignment: .bottom)

                    Text("\(summary.count)")
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity)
    }

    private func barHeight(for count: Int) -> CGFloat {
        guard count > 0 else { return 4 }
        return max(8, CGFloat(count) / CGFloat(maximumCount) * 34)
    }
}

private struct DailyScheduleItemEditorSheet: View {
    let languageManager: LanguageManager
    let originalItem: DailyScheduleItem?
    let onSave: (DailyScheduleItem) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var startDate: Date
    @State private var hasEndDate: Bool
    @State private var endDate: Date
    @State private var notes: String
    @State private var reminderLeadMinutes: Int
    @State private var isReminderEnabled: Bool

    init(
        languageManager: LanguageManager,
        item: DailyScheduleItem? = nil,
        onSave: @escaping (DailyScheduleItem) -> Void
    ) {
        let defaultStartDate = Date()
        let resolvedStartDate = item?.startDate ?? defaultStartDate
        let resolvedEndDate = item?.endDate ?? resolvedStartDate.addingTimeInterval(60 * 60)

        self.languageManager = languageManager
        self.originalItem = item
        self.onSave = onSave
        _title = State(initialValue: item?.title ?? "")
        _startDate = State(initialValue: resolvedStartDate)
        _hasEndDate = State(initialValue: item?.endDate != nil)
        _endDate = State(initialValue: resolvedEndDate)
        _notes = State(initialValue: item?.notes ?? "")
        _reminderLeadMinutes = State(initialValue: item?.reminderLeadMinutes ?? 10)
        _isReminderEnabled = State(initialValue: item?.isReminderEnabled ?? true)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStringKey(originalItem == nil ? "dashboard.add.title" : "dashboard.edit.title"))
                .font(.headline)

            Form {
                TextField("dashboard.field.title", text: $title)

                DatePicker(
                    "dashboard.field.start_time",
                    selection: $startDate,
                    displayedComponents: [.hourAndMinute]
                )

                Toggle(isOn: $hasEndDate) {
                    Text("dashboard.field.has_end_time")
                }

                if hasEndDate {
                    DatePicker(
                        "dashboard.field.end_time",
                        selection: $endDate,
                        displayedComponents: [.hourAndMinute]
                    )
                }

                Toggle(isOn: $isReminderEnabled) {
                    Text("dashboard.field.reminder_enabled")
                }

                Stepper(value: $reminderLeadMinutes, in: 0...120, step: 5) {
                    Text(String(
                        format: languageManager.localizedString("dashboard.field.lead_minutes_format"),
                        reminderLeadMinutes
                    ))
                }

                TextField("dashboard.field.notes", text: $notes, axis: .vertical)
                    .lineLimit(2...4)
            }
            .formStyle(.grouped)

            if !isValid {
                Text(validationMessage)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            HStack {
                Spacer()

                Button("cancel") {
                    dismiss()
                }

                Button(LocalizedStringKey(originalItem == nil ? "dashboard.add.action" : "dashboard.edit.action")) {
                    save()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(!isValid)
            }
        }
        .padding(20)
        .frame(minWidth: 420, minHeight: 420)
        .onChange(of: startDate) { _, newValue in
            if endDate <= newValue {
                endDate = newValue.addingTimeInterval(60 * 60)
            }
        }
    }

    private var isValid: Bool {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return false
        }

        if hasEndDate {
            return endDate > startDate
        }

        return true
    }

    private var validationMessage: String {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return languageManager.localizedString("dashboard.validation.title_required")
        }

        return languageManager.localizedString("dashboard.validation.end_after_start")
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        let item = DailyScheduleItem(
            id: originalItem?.id ?? UUID(),
            title: trimmedTitle,
            startDate: startDate,
            endDate: hasEndDate ? endDate : nil,
            notes: trimmedNotes.isEmpty ? nil : trimmedNotes,
            reminderLeadMinutes: reminderLeadMinutes,
            isReminderEnabled: isReminderEnabled,
            lastRemindedDate: originalItem?.lastRemindedDate,
            snoozedUntilDate: originalItem?.snoozedUntilDate
        )

        onSave(item)
        dismiss()
    }
}

private struct DailyScheduleImportSheet: View {
    let languageManager: LanguageManager
    let onImport: ([DailyScheduleItem]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var importText = ""
    @State private var errors: [DailyScheduleImportError] = []

    private let parser = DailyScheduleImportParser()

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("dashboard.import.title")
                .font(.headline)

            TextEditor(text: $importText)
                .font(.system(.body, design: .monospaced))
                .frame(minWidth: 480, minHeight: 220)
                .overlay {
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(.separator, lineWidth: 1)
                }

            if !errors.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("dashboard.import.errors_title")
                        .font(.subheadline.weight(.semibold))

                    ForEach(errors) { error in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(
                                format: languageManager.localizedString("dashboard.import.error.line_format"),
                                error.lineNumber,
                                error.line
                            ))
                            .lineLimit(1)

                            Text(LocalizedStringKey(error.reason.localizationKey))
                                .font(.caption)
                                .foregroundStyle(.red)
                        }
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
            }

            HStack {
                Spacer()

                Button("cancel") {
                    dismiss()
                }

                Button("dashboard.import.action") {
                    importSchedule()
                }
                .keyboardShortcut(.defaultAction)
                .disabled(importText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(20)
    }

    private func importSchedule() {
        let result = parser.parse(importText)
        errors = result.errors

        if !result.items.isEmpty {
            onImport(result.items)
        }

        if result.errors.isEmpty {
            dismiss()
        }
    }
}

private enum DailyScheduleText {
    static func timeRange(for item: DailyScheduleItem, languageManager: LanguageManager) -> String {
        if let endDate = item.endDate {
            return String(
                format: languageManager.localizedString("dashboard.time_range_format"),
                item.startDate.formatted(date: .omitted, time: .shortened),
                endDate.formatted(date: .omitted, time: .shortened)
            )
        }

        return item.startDate.formatted(date: .omitted, time: .shortened)
    }
}

#Preview {
    let settings = AppSettings()
    let preferencesStore = PreferencesStore(settings: settings)
    let languageManager = LanguageManager(preferencesStore: preferencesStore)
    let scheduleStore = DailyScheduleStore(defaults: settings.defaults)

    scheduleStore.add(
        title: "Product meeting",
        startDate: .now.addingTimeInterval(900),
        endDate: .now.addingTimeInterval(3600)
    )

    return DailyScheduleDashboardView(languageManager: languageManager, scheduleStore: scheduleStore)
        .frame(width: 760, height: 520)
}
