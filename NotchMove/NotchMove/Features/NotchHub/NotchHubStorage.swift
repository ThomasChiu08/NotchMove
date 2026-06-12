//
//  NotchHubStorage.swift
//  NotchMove
//
//  Created by Codex on 6/6/26.
//

import AppKit
import Foundation
import Observation
import UniformTypeIdentifiers

@MainActor
@Observable
final class QuickNotesStore {
    private enum Keys {
        static let text = "notchHub.notes.text"
    }

    private let defaults: UserDefaults

    var text: String {
        didSet {
            defaults.set(text, forKey: Keys.text)
        }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        text = defaults.string(forKey: Keys.text) ?? ""
    }
}

struct FileTrayItem: Codable, Equatable, Identifiable {
    let id: UUID
    var bookmarkData: Data
    var displayName: String
    var addedAt: Date

    init(id: UUID = UUID(), bookmarkData: Data, displayName: String, addedAt: Date = .now) {
        self.id = id
        self.bookmarkData = bookmarkData
        self.displayName = displayName
        self.addedAt = addedAt
    }
}

enum FileTrayError: LocalizedError, Equatable {
    case bookmarkCreationFailed(String)
    case bookmarkResolutionFailed(String)
    case airDropUnavailable

    var errorDescription: String? {
        switch self {
        case .bookmarkCreationFailed(let message):
            "Could not add file: \(message)"
        case .bookmarkResolutionFailed(let message):
            "Could not open file: \(message)"
        case .airDropUnavailable:
            "AirDrop sharing is not available."
        }
    }
}

@MainActor
@Observable
final class FileTrayStore {
    static let fileURLTypeIdentifier = UTType.fileURL.identifier

    private enum Keys {
        static let items = "notchHub.fileTray.items"
    }

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private(set) var items: [FileTrayItem] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        load()
    }

    func add(_ urls: [URL]) throws {
        for url in urls {
            let bookmarkData: Data
            do {
                bookmarkData = try url.bookmarkData(
                    options: [.withSecurityScope],
                    includingResourceValuesForKeys: [.localizedNameKey],
                    relativeTo: nil
                )
            } catch {
                throw FileTrayError.bookmarkCreationFailed(error.localizedDescription)
            }

            if items.contains(where: { $0.bookmarkData == bookmarkData }) {
                continue
            }

            items.insert(
                FileTrayItem(
                    bookmarkData: bookmarkData,
                    displayName: url.lastPathComponent.isEmpty ? url.path : url.lastPathComponent
                ),
                at: 0
            )
        }

        trimIfNeeded()
        save()
    }

    func remove(_ item: FileTrayItem) {
        items.removeAll { $0.id == item.id }
        save()
    }

    func open(_ item: FileTrayItem) {
        guard let url = try? resolvedURL(for: item) else { return }
        let didStartAccess = url.startAccessingSecurityScopedResource()
        NSWorkspace.shared.open(url)
        if didStartAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func reveal(_ item: FileTrayItem) {
        guard let url = try? resolvedURL(for: item) else { return }
        let didStartAccess = url.startAccessingSecurityScopedResource()
        NSWorkspace.shared.activateFileViewerSelecting([url])
        if didStartAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func shareViaAirDrop(_ item: FileTrayItem) throws {
        guard let sharingService = NSSharingService(named: .sendViaAirDrop) else {
            throw FileTrayError.airDropUnavailable
        }

        let url = try resolvedURL(for: item)
        let didStartAccess = url.startAccessingSecurityScopedResource()
        sharingService.perform(withItems: [url])
        if didStartAccess {
            url.stopAccessingSecurityScopedResource()
        }
    }

    func resolvedURL(for item: FileTrayItem) throws -> URL {
        do {
            var isStale = false
            let url = try URL(
                resolvingBookmarkData: item.bookmarkData,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            if isStale {
                try refreshBookmark(for: item, resolvedURL: url)
            }
            return url
        } catch {
            throw FileTrayError.bookmarkResolutionFailed(error.localizedDescription)
        }
    }

    private func refreshBookmark(for item: FileTrayItem, resolvedURL: URL) throws {
        guard let index = items.firstIndex(where: { $0.id == item.id }) else { return }
        let refreshed = try resolvedURL.bookmarkData(
            options: [.withSecurityScope],
            includingResourceValuesForKeys: [.localizedNameKey],
            relativeTo: nil
        )
        items[index].bookmarkData = refreshed
        save()
    }

    private func trimIfNeeded() {
        if items.count > 12 {
            items = Array(items.prefix(12))
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: Keys.items),
              let decodedItems = try? decoder.decode([FileTrayItem].self, from: data)
        else {
            items = []
            return
        }
        items = decodedItems
    }

    private func save() {
        guard let data = try? encoder.encode(items) else { return }
        defaults.set(data, forKey: Keys.items)
    }
}
