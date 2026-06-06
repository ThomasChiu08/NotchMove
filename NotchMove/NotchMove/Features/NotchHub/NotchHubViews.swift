//
//  NotchHubViews.swift
//  NotchMove
//
//  Created by Codex on 6/6/26.
//

import AppKit
import AVFoundation
import Foundation
import SwiftUI
import UniformTypeIdentifiers

struct NotchHubContentView: View {
    @Bindable var hubStore: NotchHubStore
    let reminderEngine: ReminderEngine
    let topInset: CGFloat

    @State private var shortcutName = ""
    @State private var isFileTargeted = false

    private enum Layout {
        static let horizontalPadding: CGFloat = 18
        static let topPadding: CGFloat = 8
        static let contentHeight: CGFloat = 206
        static let widgetButtonSize: CGFloat = 34
    }

    var body: some View {
        VStack(spacing: 10) {
            header
            widgetContent
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, topInset + Layout.topPadding)
        .padding(.bottom, 14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            hubStore.refreshActiveWidget()
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            ForEach(hubStore.enabledWidgets) { widgetID in
                Button {
                    hubStore.selectWidget(widgetID)
                } label: {
                    Image(systemName: widgetID.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(hubStore.activeWidgetID == widgetID ? .black : .white.opacity(0.76))
                        .frame(width: Layout.widgetButtonSize, height: Layout.widgetButtonSize)
                        .background {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(hubStore.activeWidgetID == widgetID ? .white : .white.opacity(0.10))
                        }
                }
                .buttonStyle(.plain)
                .help(Text(LocalizedStringKey(widgetID.titleKey)))
            }

            Spacer(minLength: 6)

            Button {
                hubStore.collapse()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .frame(width: 30, height: 30)
                    .background {
                        Circle().fill(.white.opacity(0.10))
                    }
            }
            .buttonStyle(.plain)
            .help(Text("notch_hub.close"))
        }
    }

    @ViewBuilder
    private var widgetContent: some View {
        switch hubStore.presentation {
        case .permissionPrompt(let permission):
            permissionPrompt(permission)
        case .transientError(let message):
            transientError(message)
        case .tucked, .peek, .expanded, .widget:
            activeWidgetContent
        }
    }

    @ViewBuilder
    private var activeWidgetContent: some View {
        switch hubStore.activeWidgetID {
        case .live:
            liveWidget
        case .media:
            mediaWidget
        case .calendar:
            calendarWidget
        case .shortcuts:
            shortcutsWidget
        case .notes:
            notesWidget
        case .mirror:
            mirrorWidget
        case .tray:
            trayWidget
        }
    }

    private var liveWidget: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let preview = reminderEngine.nextReminderPreview(at: context.date)
            VStack(alignment: .leading, spacing: 14) {
                widgetTitle("notch_hub.widget.live", systemImage: "waveform.path.ecg")

                VStack(alignment: .leading, spacing: 8) {
                    liveStatusRow(preview.breakRow)
                    liveStatusRow(preview.pomodoroRow)
                }

                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: Layout.contentHeight, maxHeight: Layout.contentHeight, alignment: .topLeading)
        }
    }

    private func liveStatusRow(_ row: ReminderEngine.NextReminderPreview.Row) -> some View {
        HStack(spacing: 10) {
            Image(systemName: row.mode == .breakReminder ? "figure.stand" : "timer")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.72))
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(LocalizedStringKey(row.mode == .breakReminder ? "notch.preview.break_title" : "notch.preview.pomodoro_title"))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.54))

                Text(liveStatusText(row))
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private var mediaWidget: some View {
        VStack(alignment: .leading, spacing: 14) {
            widgetTitle("notch_hub.widget.media", systemImage: "play.circle")

            VStack(alignment: .leading, spacing: 3) {
                Text(mediaTitle)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(mediaSubtitle)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.58))
                    .lineLimit(1)
            }

            HStack(spacing: 10) {
                hubIconButton("backward.fill") {
                    hubStore.performMediaCommand(.previous)
                }
                hubIconButton(hubStore.mediaStatus.playbackState == .playing ? "pause.fill" : "play.fill") {
                    hubStore.performMediaCommand(.playPause)
                }
                hubIconButton("forward.fill") {
                    hubStore.performMediaCommand(.next)
                }
                hubIconButton("music.note") {
                    hubStore.performMediaCommand(.openPreferredPlayer)
                }
            }
            .disabled(!hubStore.preferences.allowAppleEvents)

            if !hubStore.preferences.allowAppleEvents {
                permissionInline("notch_hub.permission.apple_events") {
                    hubStore.preferences.allowAppleEvents = true
                    hubStore.refreshActiveWidget()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: Layout.contentHeight, maxHeight: Layout.contentHeight, alignment: .topLeading)
    }

    private var calendarWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                widgetTitle("notch_hub.widget.calendar", systemImage: "calendar")
                Spacer()
                Button("notch_hub.refresh") {
                    Task { await hubStore.refreshCalendarItems() }
                }
                .controlSize(.small)
            }

            if hubStore.upcomingCalendarItems.isEmpty {
                emptyState("notch_hub.calendar.empty", systemImage: "calendar.badge.clock")
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(hubStore.upcomingCalendarItems.prefix(4)) { item in
                        calendarRow(item)
                    }
                }
            }

            if !hubStore.preferences.allowCalendarAccess {
                permissionInline("notch_hub.permission.calendar") {
                    hubStore.requestCalendarAccess()
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: Layout.contentHeight, maxHeight: Layout.contentHeight, alignment: .topLeading)
    }

    private var shortcutsWidget: some View {
        VStack(alignment: .leading, spacing: 12) {
            widgetTitle("notch_hub.widget.shortcuts", systemImage: "command")

            HStack(spacing: 8) {
                TextField("notch_hub.shortcuts.placeholder", text: $shortcutName)
                    .textFieldStyle(.roundedBorder)

                Button("notch_hub.add") {
                    hubStore.addShortcut(named: shortcutName)
                    shortcutName = ""
                }
                .disabled(shortcutName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            if hubStore.preferences.shortcutNames.isEmpty {
                emptyState("notch_hub.shortcuts.empty", systemImage: "command")
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(hubStore.preferences.shortcutNames, id: \.self) { shortcut in
                        HStack(spacing: 8) {
                            Button(shortcut) {
                                hubStore.runShortcut(named: shortcut)
                            }
                            .buttonStyle(.bordered)
                            .lineLimit(1)

                            Button {
                                hubStore.removeShortcut(named: shortcut)
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white.opacity(0.62))
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, minHeight: Layout.contentHeight, maxHeight: Layout.contentHeight, alignment: .topLeading)
    }

    private var notesWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetTitle("notch_hub.widget.notes", systemImage: "note.text")

            TextEditor(text: Binding(
                get: { hubStore.quickNotesStore.text },
                set: { hubStore.quickNotesStore.text = $0 }
            ))
            .font(.system(size: 13))
            .scrollContentBackground(.hidden)
            .background(.white.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(height: 166)
        }
        .frame(maxWidth: .infinity, minHeight: Layout.contentHeight, maxHeight: Layout.contentHeight, alignment: .topLeading)
    }

    private var mirrorWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetTitle("notch_hub.widget.mirror", systemImage: "camera.viewfinder")

            if hubStore.preferences.allowCameraAccess &&
                hubStore.cameraPermissionProvider.authorizationStatus == .authorized {
                CameraMirrorPreview()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .frame(height: 166)
            } else {
                VStack(spacing: 10) {
                    emptyState("notch_hub.mirror.permission_needed", systemImage: "camera.viewfinder")
                    Button("notch_hub.request_access") {
                        hubStore.requestCameraAccess()
                    }
                    .controlSize(.small)
                }
                .frame(maxWidth: .infinity, minHeight: 166)
            }
        }
        .frame(maxWidth: .infinity, minHeight: Layout.contentHeight, maxHeight: Layout.contentHeight, alignment: .topLeading)
    }

    private var trayWidget: some View {
        VStack(alignment: .leading, spacing: 10) {
            widgetTitle("notch_hub.widget.tray", systemImage: "tray.full")

            VStack(spacing: 8) {
                if hubStore.fileTrayStore.items.isEmpty {
                    emptyState("notch_hub.tray.empty", systemImage: "tray.and.arrow.down")
                        .frame(maxWidth: .infinity, minHeight: 76)
                } else {
                    ScrollView {
                        VStack(spacing: 6) {
                            ForEach(hubStore.fileTrayStore.items.prefix(5)) { item in
                                trayRow(item)
                            }
                        }
                    }
                    .frame(height: 118)
                }

                Text("notch_hub.tray.drop_hint")
                    .font(.caption2)
                    .foregroundStyle(isFileTargeted ? .white : .white.opacity(0.52))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(
                                isFileTargeted ? .white.opacity(0.64) : .white.opacity(0.18),
                                style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                            )
                    }
            }
        }
        .frame(maxWidth: .infinity, minHeight: Layout.contentHeight, maxHeight: Layout.contentHeight, alignment: .topLeading)
        .onDrop(
            of: [FileTrayStore.fileURLTypeIdentifier],
            isTargeted: $isFileTargeted,
            perform: hubStore.addFileItemProviders
        )
    }

    private func trayRow(_ item: FileTrayItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "doc")
                .foregroundStyle(.white.opacity(0.68))
                .frame(width: 18)

            Text(item.displayName)
                .font(.caption)
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 8)

            hubIconButton("arrow.up.forward.app") {
                hubStore.openFileTrayItem(item)
            }
            hubIconButton("finder") {
                hubStore.revealFileTrayItem(item)
            }
            hubIconButton("airplane") {
                hubStore.shareFileTrayItemViaAirDrop(item)
            }
            hubIconButton("xmark") {
                hubStore.fileTrayStore.remove(item)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
    }

    private func calendarRow(_ item: NotchHubCalendarItem) -> some View {
        HStack(spacing: 9) {
            Image(systemName: item.source == .calendar ? "calendar" : "clock")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.58))
                .frame(width: 18)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(calendarTimeText(item))
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.54))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
    }

    private func widgetTitle(_ titleKey: String, systemImage: String) -> some View {
        Label {
            Text(LocalizedStringKey(titleKey))
        } icon: {
            Image(systemName: systemImage)
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundStyle(.white.opacity(0.82))
    }

    private func hubIconButton(_ systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.82))
                .frame(width: 28, height: 28)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 7, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func emptyState(_ titleKey: String, systemImage: String) -> some View {
        VStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.title3)
                .foregroundStyle(.white.opacity(0.38))

            Text(LocalizedStringKey(titleKey))
                .font(.caption)
                .foregroundStyle(.white.opacity(0.54))
                .multilineTextAlignment(.center)
        }
    }

    private func permissionInline(_ permissionKey: String, action: @escaping () -> Void) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "lock")
                .foregroundStyle(.yellow.opacity(0.86))

            Text(LocalizedStringKey(permissionKey))
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))

            Spacer(minLength: 4)

            Button("notch_hub.enable") {
                action()
            }
            .controlSize(.small)
        }
    }

    private func permissionPrompt(_ permission: NotchHubPermission) -> some View {
        VStack(spacing: 12) {
            emptyState(permission.titleKey, systemImage: "lock")

            HStack(spacing: 8) {
                Button("notch_hub.enable") {
                    enable(permission)
                }

                Button("cancel") {
                    hubStore.presentation = .widget(hubStore.selectedWidgetID)
                }
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: Layout.contentHeight, maxHeight: Layout.contentHeight)
    }

    private func transientError(_ message: String) -> some View {
        VStack(spacing: 10) {
            emptyState("notch_hub.error.title", systemImage: "exclamationmark.triangle")

            Text(message)
                .font(.caption)
                .foregroundStyle(.white.opacity(0.62))
                .multilineTextAlignment(.center)
                .lineLimit(3)

            Button("ok") {
                hubStore.presentation = .widget(hubStore.selectedWidgetID)
            }
            .controlSize(.small)
        }
        .frame(maxWidth: .infinity, minHeight: Layout.contentHeight, maxHeight: Layout.contentHeight)
    }

    private func enable(_ permission: NotchHubPermission) {
        switch permission {
        case .appleEvents:
            hubStore.preferences.allowAppleEvents = true
        case .calendar:
            hubStore.requestCalendarAccess()
        case .shortcuts:
            break
        case .camera:
            hubStore.requestCameraAccess()
        case .files:
            hubStore.preferences.allowFileTray = true
        }
        hubStore.presentation = .widget(hubStore.selectedWidgetID)
    }

    private var mediaTitle: String {
        hubStore.mediaStatus.title ?? NSLocalizedString("notch_hub.media.no_track", comment: "")
    }

    private var mediaSubtitle: String {
        if let artist = hubStore.mediaStatus.artist, !artist.isEmpty {
            return artist
        }

        if let app = hubStore.mediaStatus.app {
            return app.displayName
        }

        return NSLocalizedString("notch_hub.media.open_player", comment: "")
    }

    private func liveStatusText(_ row: ReminderEngine.NextReminderPreview.Row) -> String {
        switch row.status {
        case .scheduled(let targetDate, let remainingSeconds):
            return "\(targetDate.formatted(date: .omitted, time: .shortened)) · \(durationText(remainingSeconds))"
        case .snoozed(let targetDate, _):
            return "\(NSLocalizedString("notch.preview.snoozed", comment: "")) · \(targetDate.formatted(date: .omitted, time: .shortened))"
        case .paused:
            return NSLocalizedString("notch.preview.paused", comment: "")
        case .disabled:
            return NSLocalizedString("notch.preview.disabled", comment: "")
        case .idle:
            return NSLocalizedString("notch.preview.idle", comment: "")
        case .scheduleBlocked:
            return NSLocalizedString("notch.preview.schedule_blocked", comment: "")
        case .idleSuppressed:
            return NSLocalizedString("notch.preview.idle_suppressed", comment: "")
        }
    }

    private func durationText(_ seconds: Int) -> String {
        let minutes = max(Int(ceil(Double(max(seconds, 0)) / 60)), 1)
        return String(format: NSLocalizedString("notch.preview.minutes_format", comment: ""), minutes)
    }

    private func calendarTimeText(_ item: NotchHubCalendarItem) -> String {
        if let endDate = item.endDate {
            return "\(item.startDate.formatted(date: .omitted, time: .shortened))-\(endDate.formatted(date: .omitted, time: .shortened))"
        }

        return item.startDate.formatted(date: .omitted, time: .shortened)
    }
}

private struct CameraMirrorPreview: NSViewRepresentable {
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> PreviewView {
        let view = PreviewView()
        context.coordinator.attach(to: view)
        return view
    }

    func updateNSView(_ nsView: PreviewView, context: Context) {}

    static func dismantleNSView(_ nsView: PreviewView, coordinator: Coordinator) {
        coordinator.stop()
    }

    final class PreviewView: NSView {
        var previewLayer: AVCaptureVideoPreviewLayer?

        override func layout() {
            super.layout()
            previewLayer?.frame = bounds
        }
    }

    final class Coordinator: @unchecked Sendable {
        private let sessionQueue = DispatchQueue(label: "com.notchmove.notchHub.cameraMirrorPreview.session")
        private let session = AVCaptureSession()
        private var isConfigured = false

        func attach(to view: PreviewView) {
            let previewLayer = AVCaptureVideoPreviewLayer(session: session)
            previewLayer.videoGravity = .resizeAspectFill
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.black.cgColor
            view.layer?.addSublayer(previewLayer)
            view.previewLayer = previewLayer
            start()
        }

        func stop() {
            sessionQueue.async { [weak self] in
                guard let self else { return }

                if session.isRunning {
                    session.stopRunning()
                }
            }
        }

        private func start() {
            sessionQueue.async { [weak self] in
                self?.configureAndStartIfNeeded()
            }
        }

        private func configureAndStartIfNeeded() {
            guard !isConfigured else {
                if !session.isRunning {
                    session.startRunning()
                }
                return
            }

            session.beginConfiguration()
            session.sessionPreset = .medium
            if let device = AVCaptureDevice.default(for: .video),
               let input = try? AVCaptureDeviceInput(device: device),
               session.canAddInput(input) {
                session.addInput(input)
            }
            session.commitConfiguration()
            isConfigured = true

            if !session.isRunning {
                session.startRunning()
            }
        }
    }
}
