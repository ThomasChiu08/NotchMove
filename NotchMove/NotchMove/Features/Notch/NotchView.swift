//
//  NotchView.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import SwiftUI

struct NotchView: View {
    let reminderEngine: ReminderEngine
    let voiceInputSession: VoiceInputSessionController
    let overlayMetrics: NotchOverlayMetrics

    private let shapeAnimation = Animation.spring(response: 0.28, dampingFraction: 0.86, blendDuration: 0.08)
    private let contentAnimation = Animation.easeOut(duration: 0.18).delay(0.055)

    var body: some View {
        ZStack(alignment: .top) {
            islandShell
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.clear)
    }

    private var islandShell: some View {
        ZStack(alignment: .top) {
            NotchShape(cornerRadius: cornerRadius)
                .fill(backgroundColor)

            contentLayer
                .clipped()
        }
        .frame(width: islandSize.width, height: islandSize.height, alignment: .top)
        .clipped()
        .animation(shapeAnimation, value: islandSize)
        .animation(shapeAnimation, value: cornerRadius)
        .onHover { hovering in
            guard !voiceInputSession.isOverlayVisible else { return }
            reminderEngine.send(.hoverChanged(hovering))
        }
    }

    private var cornerRadius: CGFloat {
        switch activePresentation {
        case .hidden, .reminderPending, .hoverPreviewPending, .hoverPreviewDismissing, .dismissAnimating: 10
        case .hoverPreview: 14
        case .presenting: 16
        }
    }

    private var activePresentation: ReminderState.PresentationPhase {
        voiceInputSession.isOverlayVisible ? .presenting : reminderEngine.overlayState.presentation
    }

    private var islandSize: CGSize {
        switch activePresentation {
        case .hidden, .reminderPending, .hoverPreviewPending, .hoverPreviewDismissing, .dismissAnimating:
            overlayMetrics.tuckedSize
        case .hoverPreview, .presenting:
            overlayMetrics.canvasSize
        }
    }

    private var backgroundColor: Color {
        if case .recording = voiceInputSession.phase {
            return Color(red: 0.08, green: 0.015, blue: 0.018)
        }

        if case .pomodoro = reminderEngine.overlayState.content,
           activePresentation == .presenting {
            return Color(red: 0.055, green: 0.033, blue: 0.012)
        }

        if case .pomodoroCountdown = reminderEngine.overlayState.content,
           activePresentation == .hoverPreview || activePresentation == .presenting {
            return Color(red: 0.055, green: 0.033, blue: 0.012)
        }

        return Color(red: 0.02, green: 0.02, blue: 0.02)
    }

    private var contentLayer: some View {
        ZStack(alignment: .top) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(contentAnimation, value: activePresentation)
        .animation(contentAnimation, value: voiceInputSession.phase)
    }

    @ViewBuilder
    private var content: some View {
        if voiceInputSession.isOverlayVisible {
            voiceInputContent
                .transition(.notchOverlayInsertion)
        } else {
            switch reminderEngine.overlayState.presentation {
            case .hidden, .hoverPreviewPending, .hoverPreviewDismissing, .dismissAnimating:
                EmptyView()
            case .reminderPending:
                reminderPendingIndicator
                    .transition(.opacity)
            case .hoverPreview:
                hoverPreviewContent
                    .transition(.notchOverlayInsertion)
            case .presenting:
                reminderContent
                    .transition(.notchOverlayInsertion)
            }
        }
    }

    @ViewBuilder
    private var voiceInputContent: some View {
        switch voiceInputSession.phase {
        case .idle:
            EmptyView()
        case .recording(let startedAt):
            VoiceRecordingContentView(
                startedAt: startedAt,
                topInset: overlayMetrics.topInset
            ) {
                voiceInputSession.cancel()
            }
        case .processing:
            VoiceProcessingContentView(topInset: overlayMetrics.topInset)
        case .inserted(let outcome):
            VoiceResultContentView(
                outcome: outcome,
                topInset: overlayMetrics.topInset
            ) {
                voiceInputSession.undoLastInsertion()
            } onDismiss: {
                voiceInputSession.cancel()
            }
        case .failed(let message):
            VoiceErrorContentView(
                message: message,
                topInset: overlayMetrics.topInset
            ) {
                voiceInputSession.cancel()
            }
        }
    }

    @ViewBuilder
    private var hoverPreviewContent: some View {
        switch reminderEngine.overlayState.content {
        case .breakCompletionCountdown(let content):
            BreakCompletionCountdownView(
                content: content,
                topInset: overlayMetrics.topInset
            )
        case .pomodoroCountdown(let content):
            PomodoroCountdownContentView(
                content: content,
                topInset: overlayMetrics.topInset
            )
        default:
            HoverPreviewView(topInset: overlayMetrics.topInset)
        }
    }

    private var reminderPendingIndicator: some View {
        ReminderPendingIndicatorView(
            reminderStartDate: reminderEngine.overlayState.reminderStartDate,
            reminderDuration: reminderEngine.overlayState.reminderDuration
        )
    }

    @ViewBuilder
    private var reminderContent: some View {
        switch reminderEngine.overlayState.content {
        case .breakReminder:
            BreakReminderContentView(
                reminderStartDate: reminderEngine.overlayState.reminderStartDate,
                reminderDuration: reminderEngine.overlayState.reminderDuration,
                topInset: overlayMetrics.topInset
            ) {
                reminderEngine.send(.completeBreak)
            } onSnooze: {
                reminderEngine.snoozeReminder(duration: 10 * 60)
            } onSkip: {
                reminderEngine.send(.dismissReminder)
            }
        case .schedule(let content):
            ScheduleReminderContentView(
                content: content,
                reminderStartDate: reminderEngine.overlayState.reminderStartDate,
                reminderDuration: reminderEngine.overlayState.reminderDuration,
                topInset: overlayMetrics.topInset
            ) {
                reminderEngine.send(.completeScheduleReminder)
            } onSnooze: {
                reminderEngine.send(.snoozeScheduleReminder(minutes: 5))
            }
        case .pomodoro(let content):
            PomodoroReminderContentView(
                content: content,
                reminderStartDate: reminderEngine.overlayState.reminderStartDate,
                reminderDuration: reminderEngine.overlayState.reminderDuration,
                topInset: overlayMetrics.topInset
            ) {
                reminderEngine.send(.dismissPomodoroReminder)
            }
        case .pomodoroCountdown(let content):
            PomodoroCountdownContentView(
                content: content,
                topInset: overlayMetrics.topInset
            )
        case .breakCompletionCountdown:
            EmptyView()
        }
    }
}

private struct ReminderPendingIndicatorView: View {
    let reminderStartDate: Date
    let reminderDuration: TimeInterval

    var body: some View {
        TimelineView(.animation) { context in
            let progress = reminderProgress(
                at: context.date,
                reminderStartDate: reminderStartDate,
                reminderDuration: reminderDuration
            )

            VStack {
                Spacer(minLength: 0)

                Capsule()
                    .fill(.green.opacity(0.86))
                    .frame(width: 66, height: 2)
                    .scaleEffect(x: (42 + 24 * CGFloat(progress)) / 66, anchor: .leading)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
    }
}

private struct VoiceRecordingContentView: View {
    let startedAt: Date
    let topInset: CGFloat
    let onCancel: () -> Void

    var body: some View {
        TimelineView(.animation) { context in
            HStack(spacing: 10) {
                Image(systemName: "waveform")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.red)
                    .symbolEffect(.pulse, options: .repeating)

                VStack(alignment: .leading, spacing: 1) {
                    Text("voice.overlay.listening")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)

                    Text(elapsedText(at: context.date))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.white.opacity(0.62))
                }

                Spacer(minLength: 8)

                Button(action: onCancel) {
                    Text("cancel")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 14)
            .padding(.top, topInset + 4)
        }
    }

    private func elapsedText(at date: Date) -> String {
        let seconds = max(Int(date.timeIntervalSince(startedAt)), 0)
        return String(format: "%02d:%02d", seconds / 60, seconds % 60)
    }
}

private struct VoiceProcessingContentView: View {
    let topInset: CGFloat

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)
                .tint(.white)

            VStack(alignment: .leading, spacing: 1) {
                Text("voice.overlay.processing")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text("voice.overlay.processing_detail")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)
        }
        .padding(.horizontal, 14)
        .padding(.top, topInset + 4)
    }
}

private struct VoiceResultContentView: View {
    let outcome: TextInsertionOutcome
    let topInset: CGFloat
    let onUndo: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(.caption, weight: .semibold))
                .foregroundStyle(outcome.didReachTargetApp ? .green : .yellow)

            VStack(alignment: .leading, spacing: 1) {
                Text(titleKey)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(detailKey)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }

            Spacer(minLength: 6)

            if outcome.didReachTargetApp {
                Button(action: onUndo) {
                    Text("voice.overlay.undo")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .controlSize(.small)
            } else {
                Button(action: onDismiss) {
                    Text("voice.overlay.dismiss")
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, topInset + 4)
    }

    private var iconName: String {
        outcome.didReachTargetApp ? "text.insert" : "doc.on.clipboard"
    }

    private var titleKey: LocalizedStringKey {
        switch outcome {
        case .insertedViaAccessibility, .pastedViaClipboard:
            "voice.overlay.inserted"
        case .copiedToClipboard:
            "voice.overlay.copied"
        case .failed:
            "voice.overlay.failed"
        }
    }

    private var detailKey: LocalizedStringKey {
        switch outcome {
        case .insertedViaAccessibility:
            "voice.overlay.inserted_accessibility"
        case .pastedViaClipboard:
            "voice.overlay.inserted_clipboard"
        case .copiedToClipboard:
            "voice.overlay.copied_detail"
        case .failed:
            "voice.overlay.failed_detail"
        }
    }
}

private struct VoiceErrorContentView: View {
    let message: String
    let topInset: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.caption)
                .foregroundStyle(.yellow)

            VStack(alignment: .leading, spacing: 1) {
                Text("voice.overlay.failed")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)

                Text(message)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
            }

            Spacer(minLength: 6)

            Button(action: onDismiss) {
                Text("voice.overlay.dismiss")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .controlSize(.small)
        }
        .padding(.horizontal, 14)
        .padding(.top, topInset + 4)
    }
}

private struct HoverPreviewView: View {
    let topInset: CGFloat

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "figure.stand")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.5))
            Text("next_reminder_soon")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .padding(.top, topInset + 4)
    }
}

private struct BreakCompletionCountdownView: View {
    let content: ReminderEngine.BreakCompletionCountdownContent
    let topInset: CGFloat

    var body: some View {
        TimelineView(.animation) { context in
            let progress = reminderProgress(
                at: context.date,
                reminderStartDate: content.startedAt,
                reminderDuration: content.duration
            )

            HStack(spacing: 10) {
                ReminderProgressView(progress: progress)

                VStack(alignment: .leading, spacing: 1) {
                    Text("movement_countdown_title")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    ReminderCountdownLabel(
                        remainingSeconds: remainingSeconds(
                            at: context.date,
                            reminderStartDate: content.startedAt,
                            reminderDuration: content.duration
                        )
                    )
                }

                Spacer(minLength: 6)
            }
            .padding(.horizontal, 14)
            .padding(.top, topInset + 4)
        }
    }
}

private struct BreakReminderContentView: View {
    let reminderStartDate: Date
    let reminderDuration: TimeInterval
    let topInset: CGFloat
    let onCompleteBreak: () -> Void
    let onSnooze: () -> Void
    let onSkip: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            BreakReminderTimingView(
                reminderStartDate: reminderStartDate,
                reminderDuration: reminderDuration
            )

            Spacer(minLength: 4)

            Button(action: onSnooze) {
                Text("notch.snooze_10m")
                    .lineLimit(1)
                    .minimumScaleFactor(0.65)
            }
            .controlSize(.small)

            Button(action: onSkip) {
                Text("notch.skip")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .controlSize(.small)

            Button(action: onCompleteBreak) {
                Text("stand_and_move")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .tint(.green)
        }
        .padding(.horizontal, 14)
        .padding(.top, topInset + 4)
    }
}

private struct BreakReminderTimingView: View {
    let reminderStartDate: Date
    let reminderDuration: TimeInterval

    var body: some View {
        TimelineView(.animation) { context in
            let progress = reminderProgress(
                at: context.date,
                reminderStartDate: reminderStartDate,
                reminderDuration: reminderDuration
            )

            HStack(spacing: 10) {
                ReminderProgressView(progress: progress)

                VStack(alignment: .leading, spacing: 1) {
                    Text("time_to_stretch")
                        .font(.system(.caption, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    ReminderCountdownLabel(
                        remainingSeconds: remainingSeconds(
                            at: context.date,
                            reminderStartDate: reminderStartDate,
                            reminderDuration: reminderDuration
                        )
                    )
                }
            }
        }
    }
}

private struct ScheduleReminderContentView: View {
    let content: ReminderEngine.ScheduleReminderContent
    let reminderStartDate: Date
    let reminderDuration: TimeInterval
    let topInset: CGFloat
    let onComplete: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ReminderProgressTimelineView(
                reminderStartDate: reminderStartDate,
                reminderDuration: reminderDuration
            )

            VStack(alignment: .leading, spacing: 1) {
                Text("schedule_reminder_title")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)

                Text(content.title)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text(timeRangeText)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.6))
                    .lineLimit(1)
            }

            Spacer(minLength: 6)

            Button(action: onSnooze) {
                Text("schedule_reminder_snooze")
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            .controlSize(.small)

            Button(action: onComplete) {
                Text("schedule_reminder_done")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .tint(.green)
        }
        .padding(.horizontal, 14)
        .padding(.top, topInset + 4)
    }

    private var timeRangeText: String {
        if let endDate = content.endDate {
            "\(content.startDate.formatted(date: .omitted, time: .shortened))-\(endDate.formatted(date: .omitted, time: .shortened))"
        } else {
            content.startDate.formatted(date: .omitted, time: .shortened)
        }
    }
}

private struct PomodoroCountdownContentView: View {
    let content: PomodoroCountdownContent
    let topInset: CGFloat

    var body: some View {
        TimelineView(.periodic(from: content.startedAt, by: 1)) { context in
            let remaining = pomodoroRemainingSeconds(at: context.date, content: content)

            HStack(spacing: 14) {
                PomodoroCountdownProgressView(
                    content: content,
                    remainingSeconds: remaining
                )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 7) {
                        Text(titleKey)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.58))
                            .lineLimit(1)
                            .minimumScaleFactor(0.78)

                        if content.isPaused {
                            Text("pomodoro.paused_label")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(tint.opacity(0.86))
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(
                                    Capsule()
                                        .fill(tint.opacity(0.13))
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(tint.opacity(0.22), lineWidth: 0.5)
                                )
                                .lineLimit(1)
                        }
                    }

                    Text(formattedCountdownSeconds(remaining))
                        .font(.system(size: 22, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .contentTransition(.numericText(value: Double(remaining)))
                        .animation(.easeOut(duration: 0.16), value: remaining)
                }
                .fixedSize(horizontal: true, vertical: false)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 18)
            .padding(.top, topInset + 8)
        }
    }

    private var tint: Color {
        switch content.phase {
        case .focus:
            Color(red: 1.0, green: 0.72, blue: 0.13)
        case .rest:
            Color(red: 0.32, green: 0.88, blue: 0.69)
        }
    }

    private var titleKey: LocalizedStringKey {
        switch content.phase {
        case .focus:
            "pomodoro.countdown.focus_title"
        case .rest:
            "pomodoro.countdown.break_title"
        }
    }
}

private struct PomodoroCountdownProgressView: View {
    let content: PomodoroCountdownContent
    let remainingSeconds: Int

    var body: some View {
        ProgressRingView(
            progress: progress,
            size: 42,
            lineWidth: 3,
            tint: tint,
            trackTint: tint.opacity(0.11)
        )
        .overlay {
            Image(systemName: symbolName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(tint)
        }
    }

    private var progress: Double {
        guard content.duration > 0 else { return 0 }
        return clampedProgress((content.duration - TimeInterval(remainingSeconds)) / content.duration)
    }

    private var tint: Color {
        switch content.phase {
        case .focus:
            Color(red: 1.0, green: 0.72, blue: 0.13)
        case .rest:
            Color(red: 0.32, green: 0.88, blue: 0.69)
        }
    }

    private var symbolName: String {
        switch content.phase {
        case .focus:
            "timer"
        case .rest:
            "cup.and.saucer.fill"
        }
    }
}

private struct PomodoroReminderContentView: View {
    let content: PomodoroReminderContent
    let reminderStartDate: Date
    let reminderDuration: TimeInterval
    let topInset: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            PomodoroReminderTimingView(
                content: content,
                reminderStartDate: reminderStartDate,
                reminderDuration: reminderDuration
            )

            Spacer(minLength: 4)

            Button(action: onDismiss) {
                Text(actionKey)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .tint(.green)
        }
        .padding(.horizontal, 14)
        .padding(.top, topInset + 4)
    }

    private var actionKey: LocalizedStringKey {
        switch content.kind {
        case .sessionStarted:
            "pomodoro.dismiss"
        case .focusCompleted:
            "pomodoro.start_break"
        case .breakCompleted:
            "pomodoro.done"
        }
    }
}

private struct PomodoroReminderTimingView: View {
    let content: PomodoroReminderContent
    let reminderStartDate: Date
    let reminderDuration: TimeInterval

    var body: some View {
        HStack(spacing: 10) {
            PomodoroProgressTimelineView(
                reminderStartDate: reminderStartDate,
                reminderDuration: reminderDuration,
                kind: content.kind
            )

            VStack(alignment: .leading, spacing: 1) {
                Text(titleKey)
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                detailView
            }
        }
    }

    private var titleKey: LocalizedStringKey {
        switch content.kind {
        case .sessionStarted:
            "pomodoro.session_started.title"
        case .focusCompleted:
            "pomodoro.focus_completed.title"
        case .breakCompleted:
            "pomodoro.break_completed.title"
        }
    }

    @ViewBuilder
    private var detailView: some View {
        switch content.kind {
        case .sessionStarted:
            HStack(spacing: 4) {
                Text("pomodoro.work_label")
                Text(durationText(content.focusDuration))
                    .monospacedDigit()
                Text("·")
                Text("pomodoro.rest_label")
                Text(durationText(content.breakDuration))
                    .monospacedDigit()
            }
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.66))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
        case .focusCompleted:
            Text("pomodoro.focus_completed.detail")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        case .breakCompleted:
            Text("pomodoro.break_completed.detail")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.62))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }

    private func durationText(_ duration: TimeInterval) -> String {
        let minutes = max(Int(round(duration / 60)), 1)
        return "\(minutes)m"
    }
}

private struct PomodoroProgressTimelineView: View {
    let reminderStartDate: Date
    let reminderDuration: TimeInterval
    let kind: PomodoroReminderContent.Kind

    var body: some View {
        TimelineView(.animation) { context in
            let progress = reminderProgress(
                at: context.date,
                reminderStartDate: reminderStartDate,
                reminderDuration: reminderDuration
            )

            ProgressRingView(
                progress: progress,
                size: 32,
                lineWidth: 2.5,
                tint: tint,
                trackTint: .orange.opacity(0.16)
            )
            .overlay {
                Image(systemName: symbolName)
                    .font(.caption)
                    .foregroundStyle(tint)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
    }

    private var tint: Color {
        switch kind {
        case .sessionStarted:
            .yellow
        case .focusCompleted:
            .orange
        case .breakCompleted:
            .mint
        }
    }

    private var symbolName: String {
        switch kind {
        case .sessionStarted:
            "timer"
        case .focusCompleted:
            "cup.and.saucer.fill"
        case .breakCompleted:
            "checkmark.circle.fill"
        }
    }
}

private struct ReminderProgressTimelineView: View {
    let reminderStartDate: Date
    let reminderDuration: TimeInterval

    var body: some View {
        TimelineView(.animation) { context in
            let progress = reminderProgress(
                at: context.date,
                reminderStartDate: reminderStartDate,
                reminderDuration: reminderDuration
            )

            ReminderProgressView(progress: progress)
        }
    }
}

private struct ReminderProgressView: View {
    let progress: Double

    var body: some View {
        ProgressRingView(progress: progress, size: 32, lineWidth: 2.5)
            .overlay {
                Image(systemName: stretchSymbol(for: progress))
                    .font(.caption)
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
    }
}

private struct ReminderCountdownLabel: View {
    let remainingSeconds: Int

    var body: some View {
        Text("\(remainingSeconds)s")
            .font(.caption2)
            .foregroundStyle(.white.opacity(0.6))
            .monospacedDigit()
    }
}

private struct NotchOverlayTransitionModifier: ViewModifier {
    let opacity: Double
    let scale: CGFloat
    let offsetY: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale, anchor: .top)
            .offset(y: offsetY)
    }
}

private extension AnyTransition {
    static let notchOverlayInsertion = asymmetric(
        insertion: .modifier(
            active: NotchOverlayTransitionModifier(opacity: 0, scale: 0.965, offsetY: -14),
            identity: NotchOverlayTransitionModifier(opacity: 1, scale: 1, offsetY: 0)
        ),
        removal: .opacity
    )
}

private func reminderProgress(
    at date: Date,
    reminderStartDate: Date,
    reminderDuration: TimeInterval
) -> Double {
    guard reminderDuration > 0 else { return 0 }

    let elapsed = date.timeIntervalSince(reminderStartDate)
    return clampedProgress(elapsed / reminderDuration)
}

private func remainingSeconds(
    at date: Date,
    reminderStartDate: Date,
    reminderDuration: TimeInterval
) -> Int {
    let progress = reminderProgress(
        at: date,
        reminderStartDate: reminderStartDate,
        reminderDuration: reminderDuration
    )

    return Int(ceil(reminderDuration * (1 - progress)))
}

private func pomodoroRemainingSeconds(at date: Date, content: PomodoroCountdownContent) -> Int {
    if let pausedRemainingSeconds = content.pausedRemainingSeconds {
        return max(pausedRemainingSeconds, 0)
    }

    let elapsed = max(date.timeIntervalSince(content.startedAt), 0)
    return max(Int(ceil(content.duration - elapsed)), 0)
}

private func formattedCountdownSeconds(_ seconds: Int) -> String {
    let safeSeconds = max(seconds, 0)
    return String(format: "%02d:%02d", safeSeconds / 60, safeSeconds % 60)
}

private func stretchSymbol(for progress: Double) -> String {
    switch clampedProgress(progress) {
    case ..<0.33: "figure.stand"
    case 0.33..<0.66: "figure.flexibility"
    default: "figure.walk"
    }
}

private func clampedProgress(_ progress: Double) -> Double {
    let safeProgress = progress.isFinite ? progress : 0
    return min(max(safeProgress, 0), 1)
}

@MainActor
private final class PreviewIdleProvider: IdleTimeProviding {
    var idleSeconds: TimeInterval = 0
}

@MainActor
private struct PreviewSoundPlayer: SoundPlaying {
    func playSound(_ cue: ReminderSoundCue) {}
}

#Preview {
    let settings = AppSettings()
    let preferencesStore = PreferencesStore(settings: settings)
    let breakStatsStore = BreakStatsStore(defaults: settings.defaults)
    let engine = ReminderEngine(
        activityMonitor: PreviewIdleProvider(),
        preferencesStore: preferencesStore,
        soundPlayer: PreviewSoundPlayer(),
        breakStatsStore: breakStatsStore
    )
    let overlayMetrics = NotchOverlayMetrics(topInset: 38)

    NotchView(
        reminderEngine: engine,
        voiceInputSession: VoiceInputSessionController(
            preferences: AIProviderPreferences(defaults: settings.defaults),
            languageManager: LanguageManager(preferencesStore: preferencesStore)
        ),
        overlayMetrics: overlayMetrics
    )
        .frame(width: 380, height: 160)
        .background(.gray)
        .onAppear {
            engine.send(.manualTrigger)
            engine.send(.hoverChanged(true))
        }
}
