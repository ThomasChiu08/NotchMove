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
    private lazy var notchHubStore = NotchHubStore(
        defaults: settings.defaults,
        dailyScheduleStore: dailyScheduleStore
    )
    private lazy var aiProviderPreferences = AIProviderPreferences(defaults: settings.defaults)
    private lazy var aiScheduleAssistantService = AIScheduleAssistantService(preferences: aiProviderPreferences)
    private lazy var languageManager = LanguageManager(preferencesStore: preferencesStore)
    private lazy var voiceInputSession = VoiceInputSessionController(
        preferences: aiProviderPreferences,
        preferencesStore: preferencesStore,
        languageManager: languageManager
    )

    private var activityMonitor: ActivityMonitor?
    private var reminderEngine: ReminderEngine?
    private var pomodoroEngine: PomodoroEngine?
    private var notchWindowController: NotchWindowController?
    private var menuBarController: MenuBarController?
    private var dashboardWindowController: DashboardWindowController?
    private var globalHotkeyController: GlobalAICaptureHotkeyController?
    private nonisolated(unsafe) var voiceInputPreferencesObserver: NSObjectProtocol?

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
        let pomodoro = PomodoroEngine(
            preferencesStore: preferencesStore,
            breakStatsStore: breakStatsStore,
            onReminder: { [weak engine] content in
                engine?.presentPomodoroReminder(content)
            },
            onCountdownChanged: { [weak engine] content in
                engine?.updatePomodoroCountdown(content)
            }
        )
        let globalHotkeyController = GlobalAICaptureHotkeyController(
            onPress: { [weak self] in
                guard let self,
                      self.preferencesStore.preferences.voiceInputEnabled,
                      self.reminderEngine?.isReminderPresenting != true,
                      self.pomodoroEngine?.isActive != true
                else {
                    return
                }
                self.voiceInputSession.beginPushToTalk()
            },
            onRelease: { [weak self] in
                self?.voiceInputSession.endPushToTalk()
            }
        )
        let dashboardWindow = DashboardWindowController(
            languageManager: languageManager,
            reminderEngine: engine,
            pomodoroEngine: pomodoro,
            aiAssistantService: aiScheduleAssistantService,
            scheduleStore: dailyScheduleStore,
            preferencesStore: preferencesStore,
            aiProviderPreferences: aiProviderPreferences,
            breakStatsStore: breakStatsStore,
            loginItemManager: loginItemService,
            notchHubStore: notchHubStore,
            globalHotkeyController: globalHotkeyController
        )
        let controller = NotchWindowController(
            reminderEngine: engine,
            voiceInputSession: voiceInputSession,
            notchHubStore: notchHubStore,
            languageManager: languageManager,
            preferencesStore: preferencesStore,
            onOpenDashboard: { [weak dashboardWindow] in
                dashboardWindow?.openDashboard()
            },
            onOpenSettings: { [weak dashboardWindow] in
                dashboardWindow?.openSettings(section: .reminders)
            }
        )

        monitor.start()
        engine.start()
        controller.show()

        self.activityMonitor = monitor
        self.reminderEngine = engine
        self.pomodoroEngine = pomodoro
        self.notchWindowController = controller
        self.dashboardWindowController = dashboardWindow
        self.menuBarController = MenuBarController(
            reminderEngine: engine,
            pomodoroEngine: pomodoro,
            breakStatsStore: breakStatsStore,
            languageManager: languageManager,
            preferencesStore: preferencesStore,
            notchHubStore: notchHubStore,
            voiceInputSession: voiceInputSession,
            onOpenDashboard: { [weak dashboardWindow] in
                dashboardWindow?.openDashboard()
            }
        )
        self.globalHotkeyController = globalHotkeyController
        globalHotkeyController.update(preferences: preferencesStore.preferences)
        observeVoiceInputPreferences()

        logger.notice("NotchMove launched — monitoring activity, reminder every \(engine.reminderInterval)s")
    }

    deinit {
        if let voiceInputPreferencesObserver {
            NotificationCenter.default.removeObserver(voiceInputPreferencesObserver)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func reconcileLaunchAtLogin() {
        guard !ProcessInfo.processInfo.isRunningTests else { return }
        let preferences = preferencesStore.preferences
        guard preferences.hasSeenLaunchAtLoginPrompt || preferences.launchAtLoginEnabled else { return }

        let status = loginItemService.reconcile(
            desiredEnabled: preferences.launchAtLoginEnabled
        )

        if status == .requiresApproval {
            logger.notice("Launch at login requires approval in System Settings")
        }
    }

    private func observeVoiceInputPreferences() {
        voiceInputPreferencesObserver = NotificationCenter.default.addObserver(
            forName: PreferencesStore.voiceInputDidChangeNotification,
            object: preferencesStore,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.globalHotkeyController?.update(preferences: self.preferencesStore.preferences)
            }
        }
    }
}

private extension ProcessInfo {
    var isRunningTests: Bool {
        environment["XCTestConfigurationFilePath"] != nil
    }
}
