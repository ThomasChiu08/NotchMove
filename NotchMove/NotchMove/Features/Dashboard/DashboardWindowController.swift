//
//  DashboardWindowController.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import AppKit
import SwiftUI

@MainActor
final class DashboardWindowController: NSObject, NSWindowDelegate {
    static let aiCaptureRequestedNotification = Notification.Name("DashboardWindowControllerAICaptureRequested")
    static let aiCaptureGlobalToggleRequestedNotification = Notification.Name(
        "DashboardWindowControllerAICaptureGlobalToggleRequested"
    )

    private var window: NSWindow?
    private var hostingView: NSHostingView<AnyView>?
    private let languageManager: LanguageManager
    private let reminderEngine: ReminderEngine
    private let pomodoroEngine: PomodoroEngine
    private let aiAssistantService: AIScheduleAssistantService
    private let scheduleStore: DailyScheduleStore
    private let preferencesStore: PreferencesStore
    private let aiProviderPreferences: AIProviderPreferences
    private let breakStatsStore: BreakStatsStore
    private let loginItemManager: any LoginItemManaging
    private let globalHotkeyController: GlobalAICaptureHotkeyController
    private nonisolated(unsafe) var languageObserver: NSObjectProtocol?

    init(
        languageManager: LanguageManager,
        reminderEngine: ReminderEngine,
        pomodoroEngine: PomodoroEngine,
        aiAssistantService: AIScheduleAssistantService,
        scheduleStore: DailyScheduleStore,
        preferencesStore: PreferencesStore,
        aiProviderPreferences: AIProviderPreferences,
        breakStatsStore: BreakStatsStore,
        loginItemManager: any LoginItemManaging,
        globalHotkeyController: GlobalAICaptureHotkeyController
    ) {
        self.languageManager = languageManager
        self.reminderEngine = reminderEngine
        self.pomodoroEngine = pomodoroEngine
        self.aiAssistantService = aiAssistantService
        self.scheduleStore = scheduleStore
        self.preferencesStore = preferencesStore
        self.aiProviderPreferences = aiProviderPreferences
        self.breakStatsStore = breakStatsStore
        self.loginItemManager = loginItemManager
        self.globalHotkeyController = globalHotkeyController
        super.init()

        languageObserver = NotificationCenter.default.addObserver(
            forName: LanguageManager.didChangeNotification,
            object: languageManager,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refreshWindowContent()
            }
        }
    }

    deinit {
        if let observer = languageObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    func openDashboard() {
        DispatchQueue.main.async { [weak self] in
            self?.presentWindow()
        }
    }

    func openAICapture() {
        DispatchQueue.main.async { [weak self] in
            self?.presentWindow()
        }
    }

    func toggleAICaptureFromGlobalHotkey() {
        DispatchQueue.main.async { [weak self] in
            self?.presentWindow()
        }
    }

    private func presentWindow() {
        if let existing = window {
            existing.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingView = NSHostingView(rootView: makeDashboardRootView())
        let newWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 920, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        newWindow.title = languageManager.localizedString("dashboard.unified.title")
        newWindow.contentView = hostingView
        newWindow.contentMinSize = NSSize(width: 860, height: 560)
        newWindow.isReleasedWhenClosed = false
        newWindow.delegate = self
        newWindow.level = .normal
        newWindow.center()

        window = newWindow
        self.hostingView = hostingView

        NSApp.activate(ignoringOtherApps: true)
        newWindow.makeKeyAndOrderFront(nil)
    }

    private func makeDashboardRootView() -> AnyView {
        AnyView(
            UnifiedDashboardView(
                languageManager: languageManager,
                loginItemManager: loginItemManager,
                reminderEngine: reminderEngine,
                pomodoroEngine: pomodoroEngine,
                aiAssistantService: aiAssistantService,
                scheduleStore: scheduleStore,
                preferencesStore: preferencesStore,
                aiProviderPreferences: aiProviderPreferences,
                breakStatsStore: breakStatsStore,
                globalHotkeyController: globalHotkeyController
            )
            .environment(\.locale, languageManager.locale)
        )
    }

    private func refreshWindowContent() {
        guard let window, let hostingView else { return }
        window.title = languageManager.localizedString("dashboard.unified.title")
        hostingView.rootView = makeDashboardRootView()
    }

    nonisolated func windowWillClose(_ notification: Notification) {
        Task { @MainActor in
            self.window = nil
            self.hostingView = nil
        }
    }
}
