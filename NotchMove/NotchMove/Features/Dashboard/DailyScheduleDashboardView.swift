//
//  DailyScheduleDashboardView.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Combine
import SwiftUI

struct DailyScheduleDashboardView: View {
    let languageManager: LanguageManager
    @Bindable var scheduleStore: DailyScheduleStore

    @State private var selectedItemID: DailyScheduleItem.ID?
    @State private var showingImportSheet = false
    @State private var showingClearConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var pendingDeleteItem: DailyScheduleItem?
    @State private var now = Date()

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .frame(minWidth: 680, minHeight: 460)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    showingImportSheet = true
                } label: {
                    Label("dashboard.import.button", systemImage: "square.and.arrow.down")
                }

                Button(role: .destructive) {
                    showingClearConfirmation = true
                } label: {
                    Label("dashboard.clear.button", systemImage: "trash")
                }
                .disabled(todayItems.isEmpty)
            }
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

    private var sidebar: some View {
        Group {
            if todayItems.isEmpty {
                ContentUnavailableView(
                    "dashboard.empty.title",
                    systemImage: "calendar",
                    description: Text("dashboard.empty.description")
                )
            } else {
                List(selection: $selectedItemID) {
                    Section("dashboard.today") {
                        ForEach(todayItems) { item in
                            DailyScheduleSidebarRow(item: item, languageManager: languageManager)
                                .tag(item.id)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
        }
        .navigationTitle(Text("dashboard.title"))
    }

    @ViewBuilder
    private var detail: some View {
        if let selectedItem {
            DailyScheduleDetailView(
                item: selectedItem,
                scheduleStore: scheduleStore,
                languageManager: languageManager
            ) {
                pendingDeleteItem = selectedItem
                showingDeleteConfirmation = true
            }
        } else {
            DailyScheduleOverviewView(
                currentItem: currentItem,
                nextItem: nextItem,
                languageManager: languageManager
            )
        }
    }

    private var todayItems: [DailyScheduleItem] {
        scheduleStore.itemsForToday(referenceDate: now)
    }

    private var selectedItem: DailyScheduleItem? {
        guard let selectedItemID else { return nil }
        return todayItems.first { $0.id == selectedItemID }
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

    private func ensureSelection() {
        if let selectedItemID, todayItems.contains(where: { $0.id == selectedItemID }) {
            return
        }

        selectedItemID = todayItems.first?.id
    }
}

private struct DailyScheduleSidebarRow: View {
    let item: DailyScheduleItem
    let languageManager: LanguageManager

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.isReminderEnabled ? "bell" : "bell.slash")
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .lineLimit(1)

                Text(timeRange(for: item))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private func timeRange(for item: DailyScheduleItem) -> String {
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

private struct DailyScheduleOverviewView: View {
    let currentItem: DailyScheduleItem?
    let nextItem: DailyScheduleItem?
    let languageManager: LanguageManager

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("dashboard.today")
                    .font(.title2.weight(.semibold))

                HStack(alignment: .top, spacing: 16) {
                    DailyScheduleSummaryCard(
                        titleKey: "dashboard.current",
                        emptyKey: "dashboard.none_current",
                        item: currentItem,
                        languageManager: languageManager
                    )

                    DailyScheduleSummaryCard(
                        titleKey: "dashboard.next",
                        emptyKey: "dashboard.none_next",
                        item: nextItem,
                        languageManager: languageManager
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

private struct DailyScheduleSummaryCard: View {
    let titleKey: String
    let emptyKey: String
    let item: DailyScheduleItem?
    let languageManager: LanguageManager

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(LocalizedStringKey(titleKey))
                .font(.headline)

            if let item {
                Text(item.title)
                    .font(.title3.weight(.semibold))
                    .lineLimit(2)
                Text(timeRange(for: item))
                    .foregroundStyle(.secondary)
            } else {
                Text(LocalizedStringKey(emptyKey))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func timeRange(for item: DailyScheduleItem) -> String {
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

private struct DailyScheduleDetailView: View {
    let item: DailyScheduleItem
    let scheduleStore: DailyScheduleStore
    let languageManager: LanguageManager
    let onDelete: () -> Void

    var body: some View {
        Form {
            Section {
                LabeledContent {
                    Text(timeRange(for: item))
                } label: {
                    Text("dashboard.field.time")
                }

                Toggle(isOn: reminderEnabledBinding) {
                    Text("dashboard.field.reminder_enabled")
                }

                Stepper(value: reminderLeadMinutesBinding, in: 0...120, step: 5) {
                    Text(String(
                        format: languageManager.localizedString("dashboard.field.lead_minutes_format"),
                        item.reminderLeadMinutes
                    ))
                }

                if let notes = item.notes, !notes.isEmpty {
                    LabeledContent {
                        Text(notes)
                    } label: {
                        Text("dashboard.field.notes")
                    }
                }
            } header: {
                Text(item.title)
                    .font(.title2.weight(.semibold))
            }

            Section {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Text("dashboard.delete.button")
                }
            }
        }
        .formStyle(.grouped)
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

    private func updateItem(_ update: (inout DailyScheduleItem) -> Void) {
        var updatedItem = item
        update(&updatedItem)
        scheduleStore.update(updatedItem)
    }

    private func timeRange(for item: DailyScheduleItem) -> String {
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
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
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
