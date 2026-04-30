//
//  LoginItemService.swift
//  NotchMove
//
//  Created by Codex on 4/30/26.
//

import Foundation
import OSLog
import ServiceManagement

enum LoginItemStatus: Equatable {
    case enabled
    case notRegistered
    case requiresApproval
    case notFound
}

protocol LoginItemManaging {
    var status: LoginItemStatus { get }

    func setEnabled(_ enabled: Bool) throws
    @discardableResult
    func reconcile(desiredEnabled: Bool) -> LoginItemStatus
}

final class LoginItemService: LoginItemManaging {
    private let logger: Logger
    private let service: SMAppService

    init(
        service: SMAppService = .mainApp,
        logger: Logger = Logger(subsystem: "com.thomaschiu.developer.NotchMove", category: "login-item")
    ) {
        self.service = service
        self.logger = logger
    }

    var status: LoginItemStatus {
        LoginItemStatus(service.status)
    }

    func setEnabled(_ enabled: Bool) throws {
        let currentStatus = status

        if enabled {
            guard currentStatus != .enabled && currentStatus != .requiresApproval else { return }
            try service.register()
        } else {
            guard currentStatus != .notRegistered && currentStatus != .notFound else { return }
            try service.unregister()
        }
    }

    @discardableResult
    func reconcile(desiredEnabled: Bool) -> LoginItemStatus {
        do {
            try setEnabled(desiredEnabled)
        } catch {
            logger.error("Failed to reconcile login item: \(error.localizedDescription, privacy: .public)")
        }

        return status
    }
}

private extension LoginItemStatus {
    init(_ status: SMAppService.Status) {
        switch status {
        case .enabled:
            self = .enabled
        case .notRegistered:
            self = .notRegistered
        case .requiresApproval:
            self = .requiresApproval
        case .notFound:
            self = .notFound
        @unknown default:
            self = .notFound
        }
    }
}
