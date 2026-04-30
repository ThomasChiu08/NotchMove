//
//  LanguageManager.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/17/26.
//

import Foundation

/// Manages in-app language switching at runtime.
///
/// SwiftUI views receive the locale via `.environment(\.locale, languageManager.locale)`.
/// AppKit code uses `languageManager.localizedString(_:)` for menu items and other
/// non-SwiftUI text.
///
/// Supported languages: en, zh-Hans, zh-Hant, ja.
@Observable
@MainActor
final class LanguageManager {
    /// All languages the app supports.
    struct Language: Identifiable, Hashable {
        let code: String
        let displayName: String

        var id: String { code }
    }

    static let supportedLanguages: [Language] = [
        Language(code: "en", displayName: "English"),
        Language(code: "zh-Hans", displayName: "简体中文"),
        Language(code: "zh-Hant", displayName: "繁體中文"),
        Language(code: "ja", displayName: "日本語"),
    ]

    /// Posted on the main thread when the selected language changes.
    /// AppKit controllers observe this to rebuild menus, window titles, etc.
    static let didChangeNotification = Notification.Name("LanguageManagerDidChange")

    private(set) var selectedLanguage: String

    /// The locale corresponding to the selected language.
    var locale: Locale {
        Locale(identifier: selectedLanguage)
    }

    /// A bundle pointing to the correct `.lproj` directory for the selected language.
    /// Falls back to `Bundle.main` if the lproj is missing.
    private(set) var bundle: Bundle = .main
    private let preferencesStore: PreferencesStore

    init(preferencesStore: PreferencesStore) {
        self.preferencesStore = preferencesStore
        self.selectedLanguage = preferencesStore.preferences.appLanguage
        reloadBundle()
        observePreferences()
    }

    /// Convenience for AppKit code that cannot use SwiftUI's LocalizedStringKey.
    func localizedString(_ key: String) -> String {
        NSLocalizedString(key, bundle: bundle, comment: "")
    }

    // MARK: - Private

    private func reloadBundle() {
        if let path = Bundle.main.path(forResource: selectedLanguage, ofType: "lproj"),
           let lproj = Bundle(path: path) {
            bundle = lproj
        } else {
            bundle = .main
        }
    }

    private func observePreferences() {
        withObservationTracking {
            _ = preferencesStore.preferences.appLanguage
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                self?.reloadLanguageIfNeeded()
                self?.observePreferences()
            }
        }
    }

    private func reloadLanguageIfNeeded() {
        let nextLanguage = preferencesStore.preferences.appLanguage
        guard nextLanguage != selectedLanguage else { return }
        selectedLanguage = nextLanguage
        reloadBundle()
        NotificationCenter.default.post(name: Self.didChangeNotification, object: self)
    }
}
