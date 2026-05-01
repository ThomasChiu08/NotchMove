//
//  AppDelegate.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import AppKit
import OSLog

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "lifecycle")
    private let settings = AppSettings()
    private let loginItemService = LoginItemService()
    private lazy var preferencesStore = PreferencesStore(settings: settings)
    private lazy var breakStatsStore = BreakStatsStore(defaults: settings.defaults)
    private lazy var dailyScheduleStore = DailyScheduleStore(defaults: settings.defaults)
    private lazy var aiProviderPreferences = AIProviderPreferences(defaults: settings.defaults)
    private lazy var aiScheduleAssistantService = AIScheduleAssistantService(preferences: aiProviderPreferences)
    private lazy var languageManager = LanguageManager(preferencesStore: preferencesStore)

    private var activityMonitor: ActivityMonitor?
    private var reminderEngine: ReminderEngine?
    private var dailyScheduleReminderEngine: DailyScheduleReminderEngine?
    private var notchWindowController: NotchWindowController?
    private var menuBarController: MenuBarController?
    private var dashboardWindowController: DashboardWindowController?
    private var globalHotkeyController: GlobalAICaptureHotkeyController?
    private nonisolated(unsafe) var globalHotkeyPreferenceObserver: NSObjectProtocol?

    deinit {
        if let globalHotkeyPreferenceObserver {
            NotificationCenter.default.removeObserver(globalHotkeyPreferenceObserver)
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        reconcileLaunchAtLogin()

        let monitor = ActivityMonitor()
        let soundPlayer = SystemSoundPlayer(preferencesStore: preferencesStore)
        let engine = ReminderEngine(
            activityMonitor: monitor,
            preferencesStore: preferencesStore,
            soundPlayer: soundPlayer,
            breakStatsStore: breakStatsStore
        )
        let globalHotkeyController = GlobalAICaptureHotkeyController { [weak self] in
            self?.dashboardWindowController?.toggleAICaptureFromGlobalHotkey()
        }
        let scheduleReminderEngine = DailyScheduleReminderEngine(
            scheduleStore: dailyScheduleStore,
            soundPlayer: soundPlayer,
            presenter: DailyScheduleNotchPresenter(reminderEngine: engine)
        )
        let controller = NotchWindowController(
            reminderEngine: engine,
            languageManager: languageManager,
            preferencesStore: preferencesStore
        )
        let dashboardWindow = DashboardWindowController(
            languageManager: languageManager,
            reminderEngine: engine,
            aiAssistantService: aiScheduleAssistantService,
            scheduleStore: dailyScheduleStore,
            preferencesStore: preferencesStore,
            aiProviderPreferences: aiProviderPreferences,
            breakStatsStore: breakStatsStore,
            loginItemManager: loginItemService,
            globalHotkeyController: globalHotkeyController
        )

        monitor.start()
        engine.start()
        scheduleReminderEngine.start()
        controller.show()

        self.activityMonitor = monitor
        self.reminderEngine = engine
        self.dailyScheduleReminderEngine = scheduleReminderEngine
        self.notchWindowController = controller
        self.dashboardWindowController = dashboardWindow
        self.globalHotkeyController = globalHotkeyController
        self.menuBarController = MenuBarController(
            reminderEngine: engine,
            breakStatsStore: breakStatsStore,
            dailyScheduleStore: dailyScheduleStore,
            languageManager: languageManager,
            preferencesStore: preferencesStore,
            onOpenDashboard: { [weak dashboardWindow] in
                dashboardWindow?.openDashboard()
            },
            onOpenAICapture: { [weak dashboardWindow] in
                dashboardWindow?.openAICapture()
            }
        )
        self.globalHotkeyPreferenceObserver = NotificationCenter.default.addObserver(
            forName: PreferencesStore.aiGlobalHotkeyDidChangeNotification,
            object: preferencesStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.globalHotkeyController?.update(preferences: self.preferencesStore.preferences)
            }
        }
        globalHotkeyController.update(preferences: preferencesStore.preferences)

        logger.notice("NotchMove launched — monitoring activity, reminder every \(engine.reminderInterval)s")
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func reconcileLaunchAtLogin() {
        guard !ProcessInfo.processInfo.isRunningTests else { return }

        let status = loginItemService.reconcile(
            desiredEnabled: preferencesStore.preferences.launchAtLoginEnabled
        )

        if status == .requiresApproval {
            logger.notice("Launch at login requires approval in System Settings")
        }
    }
}

private extension ProcessInfo {
    var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}
