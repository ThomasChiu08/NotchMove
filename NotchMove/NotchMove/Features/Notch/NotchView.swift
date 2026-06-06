//
//  NotchView.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import AppKit
import SwiftUI

enum NotchMotionRole: Equatable {
    case standard
    case pomodoroCountdown
}

enum NotchMotion {
    static let intentCue = Animation.interactiveSpring(response: 0.18, dampingFraction: 0.90, blendDuration: 0)
    static let expansion = Animation.interactiveSpring(response: 0.34, dampingFraction: 0.86, blendDuration: 0.02)
    static let retraction = Animation.spring(response: 0.28, dampingFraction: 0.95, blendDuration: 0.04)
    static let contentInsertion = Animation.easeOut(duration: 0.18).delay(0.13)
    static let contentRemoval = Animation.easeOut(duration: 0.09)
    static let hoverContentReveal = Animation.easeOut(duration: 0.18)
    static let hoverContentRemoval = Animation.easeOut(duration: 0.09)
    static let shadow = Animation.easeOut(duration: 0.16)
    static let pomodoroIntentCue = Animation.interactiveSpring(response: 0.16, dampingFraction: 0.94, blendDuration: 0)
    static let pomodoroExpansion = Animation.interactiveSpring(response: 0.26, dampingFraction: 0.88, blendDuration: 0.01)
    static let pomodoroRetraction = Animation.spring(response: 0.24, dampingFraction: 0.96, blendDuration: 0.03)
    static let pomodoroContentInsertion = Animation.easeOut(duration: 0.14).delay(0.07)
    static let pomodoroContentRemoval = Animation.easeOut(duration: 0.08)

    static func shellAnimation(
        for presentation: ReminderState.PresentationPhase,
        role: NotchMotionRole = .standard
    ) -> Animation {
        if role == .pomodoroCountdown {
            switch presentation {
            case .reminderPending, .hoverPreviewPending:
                return pomodoroIntentCue
            case .hoverPreview, .presenting:
                return pomodoroExpansion
            case .hidden, .hoverPreviewDismissing, .dismissAnimating:
                return pomodoroRetraction
            }
        }

        switch presentation {
        case .reminderPending, .hoverPreviewPending:
            return intentCue
        case .hoverPreview, .presenting:
            return expansion
        case .hidden, .hoverPreviewDismissing, .dismissAnimating:
            return retraction
        }
    }

    static func contentAnimation(visible: Bool, role: NotchMotionRole) -> Animation {
        switch (visible, role) {
        case (true, .pomodoroCountdown):
            pomodoroContentInsertion
        case (false, .pomodoroCountdown):
            pomodoroContentRemoval
        case (true, .standard):
            contentInsertion
        case (false, .standard):
            contentRemoval
        }
    }

    static func hoverContentAnimation(visible: Bool) -> Animation {
        visible ? hoverContentReveal : hoverContentRemoval
    }
}

enum NotchOverlayContentRole: Equatable {
    case voice
    case empty
    case reminderPending
    case hoverPreview
    case pomodoroCountdown
    case reminder

    static func resolve(
        presentation: ReminderState.PresentationPhase,
        content: ReminderEngine.OverlayContent,
        voiceOverlayVisible: Bool
    ) -> NotchOverlayContentRole {
        if voiceOverlayVisible {
            return .voice
        }

        switch presentation {
        case .hidden, .dismissAnimating:
            return .empty
        case .hoverPreviewPending, .hoverPreviewDismissing:
            if case .pomodoroCountdown = content {
                return .pomodoroCountdown
            }

            return .hoverPreview
        case .reminderPending:
            return .reminderPending
        case .hoverPreview:
            if case .pomodoroCountdown = content {
                return .pomodoroCountdown
            }

            return .hoverPreview
        case .presenting:
            return .reminder
        }
    }
}

private enum NotchHoverTiming {
    static let contentRevealDelay: Duration = .milliseconds(120)
    static let shellCollapseHoldDelay: Duration = .milliseconds(90)
}

struct NotchVisualState: Equatable {
    let shellSize: CGSize
    let shellScale: CGFloat
    let shellOffsetY: CGFloat
    let cornerRadius: CGFloat
    let shadowOpacity: Double
    let shadowRadius: CGFloat
    let shadowOffsetY: CGFloat
    let rimOpacity: Double
    let contentOpacity: Double
    let contentScale: CGFloat
    let contentOffsetY: CGFloat
    let contentBlurRadius: CGFloat

    init(
        presentation: ReminderState.PresentationPhase,
        voiceOverlayVisible: Bool,
        tuckedSize: CGSize,
        canvasSize: CGSize,
        revealHoverPreviewContent: Bool = true,
        holdHoverPreviewShellExpanded: Bool = false,
        motionRole: NotchMotionRole = .standard
    ) {
        let expandedShell = voiceOverlayVisible ||
            presentation == .hoverPreview ||
            presentation == .presenting ||
            (presentation == .hoverPreviewDismissing && holdHoverPreviewShellExpanded)
        shellSize = expandedShell ? canvasSize : tuckedSize
        let usesPomodoroCountdownMotion = motionRole == .pomodoroCountdown && !voiceOverlayVisible

        switch presentation {
        case .hidden:
            shellScale = 1
            shellOffsetY = 0
            cornerRadius = 10
            shadowOpacity = 0
            shadowRadius = 0
            shadowOffsetY = 0
            rimOpacity = 0
            contentOpacity = voiceOverlayVisible ? 1 : 0
            contentScale = voiceOverlayVisible ? 1 : 0.94
            contentOffsetY = voiceOverlayVisible ? 0 : -16
            contentBlurRadius = voiceOverlayVisible ? 0 : 8
        case .reminderPending:
            shellScale = 1.01
            shellOffsetY = 1
            cornerRadius = 11
            shadowOpacity = 0.08
            shadowRadius = 2
            shadowOffsetY = 1
            rimOpacity = 0.04
            contentOpacity = 1
            contentScale = 1
            contentOffsetY = 0
            contentBlurRadius = 0
        case .hoverPreviewPending:
            shellScale = 1.012
            shellOffsetY = 1
            cornerRadius = 11
            shadowOpacity = 0.08
            shadowRadius = 2
            shadowOffsetY = 1
            rimOpacity = 0.04
            contentOpacity = 0
            contentScale = 0.96
            contentOffsetY = -12
            contentBlurRadius = 8
        case .hoverPreview:
            shellScale = 1
            shellOffsetY = 0
            cornerRadius = usesPomodoroCountdownMotion ? 16 : 18
            shadowOpacity = usesPomodoroCountdownMotion ? 0.20 : 0.30
            shadowRadius = usesPomodoroCountdownMotion ? 8 : 12
            shadowOffsetY = usesPomodoroCountdownMotion ? 3 : 5
            rimOpacity = usesPomodoroCountdownMotion ? 0.18 : 0.10
            contentOpacity = revealHoverPreviewContent ? 1 : 0
            contentScale = revealHoverPreviewContent ? 1 : 0.96
            contentOffsetY = revealHoverPreviewContent ? 0 : -12
            contentBlurRadius = revealHoverPreviewContent ? 0 : 8
        case .presenting:
            shellScale = 1
            shellOffsetY = 0
            cornerRadius = usesPomodoroCountdownMotion ? 16 : 20
            shadowOpacity = usesPomodoroCountdownMotion ? 0.22 : 0.34
            shadowRadius = usesPomodoroCountdownMotion ? 9 : 14
            shadowOffsetY = usesPomodoroCountdownMotion ? 3 : 6
            rimOpacity = usesPomodoroCountdownMotion ? 0.18 : 0.11
            contentOpacity = 1
            contentScale = 1
            contentOffsetY = 0
            contentBlurRadius = 0
        case .hoverPreviewDismissing, .dismissAnimating:
            shellScale = holdHoverPreviewShellExpanded ? 1 : 0.992
            shellOffsetY = 0
            cornerRadius = holdHoverPreviewShellExpanded ? (usesPomodoroCountdownMotion ? 16 : 18) : 10
            shadowOpacity = holdHoverPreviewShellExpanded ? (usesPomodoroCountdownMotion ? 0.14 : 0.20) : 0.02
            shadowRadius = holdHoverPreviewShellExpanded ? (usesPomodoroCountdownMotion ? 6 : 8) : 1
            shadowOffsetY = holdHoverPreviewShellExpanded ? 3 : 1
            rimOpacity = 0
            contentOpacity = voiceOverlayVisible ? 1 : 0
            contentScale = voiceOverlayVisible ? 1 : 0.97
            contentOffsetY = voiceOverlayVisible ? 0 : -10
            contentBlurRadius = voiceOverlayVisible ? 0 : 5
        }
    }
}

struct NotchView: View {
    let reminderEngine: ReminderEngine
    let voiceInputSession: VoiceInputSessionController
    let notchHubStore: NotchHubStore
    let overlayMetrics: NotchOverlayMetrics
    let onOpenDashboard: () -> Void
    let onOpenSettings: () -> Void

    @State private var revealHoverPreviewContent = false
    @State private var holdHoverPreviewShellExpanded = false
    @State private var hoverContentRevealTask: Task<Void, Never>?
    @State private var hoverShellCollapseTask: Task<Void, Never>?

    var body: some View {
        ZStack(alignment: .top) {
            islandShell
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(.clear)
        .onAppear {
            updateHoverMotionState(for: activePresentation)
        }
        .onChange(of: activePresentation) { _, newValue in
            updateHoverMotionState(for: newValue)
        }
        .onDisappear {
            cancelHoverMotionTasks()
        }
    }

    private var islandShell: some View {
        let state = visualState

        return ZStack(alignment: .top) {
            NotchShape(cornerRadius: state.cornerRadius)
                .fill(backgroundColor)
                .overlay(alignment: .bottom) {
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0),
                            rimColor.opacity(state.rimOpacity)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(height: min(18, state.shellSize.height * 0.28))
                    .clipShape(NotchShape(cornerRadius: state.cornerRadius))
                    .allowsHitTesting(false)
                }

            contentLayer
                .clipped()
        }
        .frame(width: state.shellSize.width, height: state.shellSize.height, alignment: .top)
        .clipped()
        .scaleEffect(state.shellScale, anchor: .top)
        .offset(y: state.shellOffsetY)
        .shadow(
            color: .black.opacity(state.shadowOpacity),
            radius: state.shadowRadius,
            x: 0,
            y: state.shadowOffsetY
        )
        .animation(shellAnimation, value: state.shellSize)
        .animation(shellAnimation, value: state.shellScale)
        .animation(shellAnimation, value: state.shellOffsetY)
        .animation(shellAnimation, value: state.cornerRadius)
        .animation(NotchMotion.shadow, value: state.shadowOpacity)
        .animation(NotchMotion.shadow, value: state.shadowRadius)
        .animation(NotchMotion.shadow, value: state.shadowOffsetY)
        .animation(NotchMotion.shadow, value: state.rimOpacity)
        .onHover { hovering in
            guard !voiceInputSession.isOverlayVisible,
                  !isHubSurfaceActive
            else {
                return
            }
            reminderEngine.send(.hoverChanged(hovering))
        }
        .onTapGesture {
            guard canOpenHubFromTap else { return }
            notchHubStore.open()
        }
        .contextMenu {
            Button("menu.dashboard", action: onOpenDashboard)

            Divider()

            Button("menu.quit") {
                NSApp.terminate(nil)
            }
        }
    }

    private var visualState: NotchVisualState {
        NotchVisualState(
            presentation: activePresentation,
            voiceOverlayVisible: voiceInputSession.isOverlayVisible,
            tuckedSize: overlayMetrics.tuckedSize,
            canvasSize: overlayMetrics.canvasSize,
            revealHoverPreviewContent: revealHoverPreviewContent,
            holdHoverPreviewShellExpanded: holdHoverPreviewShellExpanded,
            motionRole: motionRole
        )
    }

    private var shellAnimation: Animation {
        NotchMotion.shellAnimation(for: activePresentation, role: motionRole)
    }

    private var contentAnimation: Animation {
        if isHoverPreviewPresentation(activePresentation) {
            return NotchMotion.hoverContentAnimation(visible: visualState.contentOpacity > 0)
        }

        return NotchMotion.contentAnimation(visible: visualState.contentOpacity > 0, role: motionRole)
    }

    private var activePresentation: ReminderState.PresentationPhase {
        if voiceInputSession.isOverlayVisible {
            return .presenting
        }

        if isHubSurfaceActive {
            return .presenting
        }

        return reminderEngine.overlayState.presentation
    }

    private var canToggleHub: Bool {
        notchHubStore.preferences.isEnabled &&
            !voiceInputSession.isOverlayVisible &&
            !reminderEngine.isReminderPresenting
    }

    private var canOpenHubFromTap: Bool {
        guard canToggleHub,
              !isHubSurfaceActive
        else {
            return false
        }

        switch notchHubStore.preferences.triggerGesture {
        case .click:
            return true
        case .hoverAndClick:
            return isHoverPreviewPresentation(reminderEngine.overlayState.presentation)
        }
    }

    private var isHubSurfaceActive: Bool {
        canToggleHub && notchHubStore.presentation.isExpandedSurface
    }

    private func isHoverPreviewPresentation(_ presentation: ReminderState.PresentationPhase) -> Bool {
        switch presentation {
        case .hoverPreviewPending, .hoverPreview, .hoverPreviewDismissing:
            return true
        case .hidden, .reminderPending, .presenting, .dismissAnimating:
            return false
        }
    }

    private var motionRole: NotchMotionRole {
        guard !isHubSurfaceActive,
              !voiceInputSession.isOverlayVisible,
              case .pomodoroCountdown = reminderEngine.overlayState.content
        else {
            return .standard
        }

        return .pomodoroCountdown
    }

    private var rimColor: Color {
        guard !voiceInputSession.isOverlayVisible,
              case .pomodoroCountdown(let content) = reminderEngine.overlayState.content
        else {
            return .white
        }

        return PomodoroOverlayStyle.tint(for: content.phase)
    }

    private var backgroundColor: Color {
        if isHubSurfaceActive {
            return Color(red: 0.018, green: 0.018, blue: 0.022)
        }

        if case .recording = voiceInputSession.phase {
            return Color(red: 0.08, green: 0.015, blue: 0.018)
        }

        return Color(red: 0.02, green: 0.02, blue: 0.02)
    }

    private var contentLayer: some View {
        let state = visualState

        return ZStack(alignment: .top) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .opacity(state.contentOpacity)
        .scaleEffect(state.contentScale, anchor: .top)
        .offset(y: state.contentOffsetY)
        .blur(radius: state.contentBlurRadius)
        .animation(contentAnimation, value: activePresentation)
        .animation(contentAnimation, value: voiceInputSession.phase)
        .animation(contentAnimation, value: state.contentOpacity)
        .animation(contentAnimation, value: state.contentBlurRadius)
        .allowsHitTesting(contentAllowsHitTesting)
    }

    private var contentAllowsHitTesting: Bool {
        if voiceInputSession.isOverlayVisible {
            return true
        }

        if isHubSurfaceActive {
            return true
        }

        switch reminderEngine.overlayState.presentation {
        case .hoverPreview:
            return revealHoverPreviewContent
        case .presenting:
            return true
        case .hidden, .reminderPending, .hoverPreviewPending, .hoverPreviewDismissing, .dismissAnimating:
            return false
        }
    }

    @ViewBuilder
    private var content: some View {
        if isHubSurfaceActive {
            NotchHubContentView(
                hubStore: notchHubStore,
                reminderEngine: reminderEngine,
                topInset: overlayMetrics.topInset
            )
            .transition(.notchOverlayInsertion)
        } else {
            switch NotchOverlayContentRole.resolve(
                presentation: reminderEngine.overlayState.presentation,
                content: reminderEngine.overlayState.content,
                voiceOverlayVisible: voiceInputSession.isOverlayVisible
            ) {
            case .voice:
                voiceInputContent
                    .transition(.notchOverlayInsertion)
            case .empty:
                EmptyView()
            case .reminderPending:
                reminderPendingIndicator
                    .transition(.opacity)
            case .hoverPreview, .pomodoroCountdown:
                hoverPreviewContent
                    .transition(.notchOverlayInsertion)
            case .reminder:
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
            NextReminderPreviewView(
                reminderEngine: reminderEngine,
                topInset: overlayMetrics.topInset,
                overlayMetrics: overlayMetrics,
                onOpenSettings: openSettingsFromHoverPreview
            )
        }
    }

    private func openSettingsFromHoverPreview() {
        reminderEngine.send(.hoverChanged(false))

        Task { @MainActor in
            try? await Task.sleep(for: ReminderEngine.hoverPreviewDismissalDelay)
            onOpenSettings()
        }
    }

    private func updateHoverMotionState(for presentation: ReminderState.PresentationPhase) {
        hoverContentRevealTask?.cancel()
        hoverContentRevealTask = nil
        hoverShellCollapseTask?.cancel()
        hoverShellCollapseTask = nil

        switch presentation {
        case .hoverPreviewPending:
            revealHoverPreviewContent = false
            holdHoverPreviewShellExpanded = false
        case .hoverPreview:
            revealHoverPreviewContent = false
            holdHoverPreviewShellExpanded = false
            hoverContentRevealTask = Task { @MainActor in
                try? await Task.sleep(for: NotchHoverTiming.contentRevealDelay)
                guard !Task.isCancelled else { return }
                revealHoverPreviewContent = true
            }
        case .hoverPreviewDismissing:
            revealHoverPreviewContent = false
            holdHoverPreviewShellExpanded = true
            hoverShellCollapseTask = Task { @MainActor in
                try? await Task.sleep(for: NotchHoverTiming.shellCollapseHoldDelay)
                guard !Task.isCancelled else { return }
                holdHoverPreviewShellExpanded = false
            }
        case .hidden, .reminderPending, .presenting, .dismissAnimating:
            revealHoverPreviewContent = false
            holdHoverPreviewShellExpanded = false
        }
    }

    private func cancelHoverMotionTasks() {
        hoverContentRevealTask?.cancel()
        hoverContentRevealTask = nil
        hoverShellCollapseTask?.cancel()
        hoverShellCollapseTask = nil
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

private struct NextReminderPreviewView: View {
    let reminderEngine: ReminderEngine
    let topInset: CGFloat
    let overlayMetrics: NotchOverlayMetrics
    let onOpenSettings: () -> Void

    @Environment(\.displayScale) private var displayScale

    private enum Layout {
        static let horizontalPadding: CGFloat = 22
        static let topPadding: CGFloat = 7
        static let bottomPadding: CGFloat = 12
        static let rowSpacing: CGFloat = 7
        static let settingsButtonSize: CGFloat = 26
        static let settingsButtonTopPadding: CGFloat = 5
        static let settingsButtonTrailingPadding: CGFloat = 8
        static let settingsReservationWidth: CGFloat = 34
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            let preview = reminderEngine.nextReminderPreview(at: context.date)

            previewContent(preview)
                .background {
                    fitProbe(preview)
                }
        }
        .onPreferenceChange(OverlayContentFitSizePreferenceKey.self) { size in
            guard size.width > 0, size.height > 0 else { return }
            overlayMetrics.requestContentFit(size: size, displayScale: displayScale)
        }
        .onDisappear {
            overlayMetrics.clearContentFitRequest()
        }
    }

    private func previewContent(_ preview: ReminderEngine.NextReminderPreview) -> some View {
        ZStack(alignment: .topTrailing) {
            previewRows(preview, fillsAvailableWidth: true)
                .padding(.trailing, Layout.settingsReservationWidth)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)

            NotchSettingsButton(
                size: Layout.settingsButtonSize,
                action: onOpenSettings
            )
            .padding(.top, topInset + Layout.settingsButtonTopPadding)
            .padding(.trailing, Layout.settingsButtonTrailingPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func previewRows(
        _ preview: ReminderEngine.NextReminderPreview,
        fillsAvailableWidth: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: Layout.rowSpacing) {
            NextReminderPreviewRowView(row: preview.breakRow, fillsAvailableWidth: fillsAvailableWidth)
            NextReminderPreviewRowView(row: preview.pomodoroRow, fillsAvailableWidth: fillsAvailableWidth)
        }
        .padding(.horizontal, Layout.horizontalPadding)
        .padding(.top, topInset + Layout.topPadding)
        .padding(.bottom, Layout.bottomPadding)
    }

    private func fitProbe(_ preview: ReminderEngine.NextReminderPreview) -> some View {
        previewRows(preview, fillsAvailableWidth: false)
        .padding(.trailing, Layout.settingsReservationWidth)
        .fixedSize(horizontal: true, vertical: true)
        .overlayContentFitSizeReporter()
        .hidden()
    }
}

private struct NotchSettingsButton: View {
    let size: CGFloat
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "gearshape")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(isHovering ? 0.96 : 0.72))
                .frame(width: size, height: size)
                .background {
                    Circle()
                        .fill(.white.opacity(isHovering ? 0.18 : 0.10))
                }
                .overlay {
                    Circle()
                        .stroke(.white.opacity(isHovering ? 0.24 : 0.12), lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .contentShape(Circle())
        .help(Text("notch.settings.open"))
        .accessibilityLabel(Text("notch.settings.open"))
        .onHover { hovering in
            isHovering = hovering
        }
        .animation(.easeOut(duration: 0.12), value: isHovering)
    }
}

private struct NextReminderPreviewRowView: View {
    let row: ReminderEngine.NextReminderPreview.Row
    var fillsAvailableWidth = true

    @ViewBuilder
    var body: some View {
        if fillsAvailableWidth {
            rowContent
                .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
        } else {
            rowContent
                .frame(minWidth: 180, alignment: .leading)
                .fixedSize(horizontal: true, vertical: true)
        }
    }

    private var rowContent: some View {
        HStack(spacing: 8) {
            Image(systemName: symbolName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 1) {
                Text(titleKey)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(isMuted ? 0.48 : 0.76))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                HStack(spacing: 4) {
                    Text(primaryText)
                        .font(.system(size: 13, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(isMuted ? 0.54 : 0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    if let secondaryText {
                        Text("·")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.26))

                        Text(secondaryText)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(isMuted ? 0.42 : 0.62))
                            .lineLimit(1)
                            .minimumScaleFactor(0.68)
                    }
                }
            }
            .layoutPriority(1)
        }
    }

    private var titleKey: LocalizedStringKey {
        switch row.mode {
        case .breakReminder:
            "notch.preview.break_title"
        case .pomodoro:
            "notch.preview.pomodoro_title"
        }
    }

    private var symbolName: String {
        switch row.mode {
        case .breakReminder:
            "figure.stand"
        case .pomodoro:
            "timer"
        }
    }

    private var tint: Color {
        if isMuted {
            return .white.opacity(0.38)
        }

        switch row.mode {
        case .breakReminder:
            return Color(red: 0.48, green: 0.86, blue: 0.62)
        case .pomodoro:
            switch row.phase {
            case .focus:
                return Color(red: 1.0, green: 0.66, blue: 0.28)
            case .rest:
                return Color(red: 0.38, green: 0.82, blue: 0.94)
            case nil:
                return Color(red: 1.0, green: 0.74, blue: 0.38)
            }
        }
    }

    private var isMuted: Bool {
        switch row.status {
        case .scheduled, .snoozed:
            false
        case .paused, .disabled, .idle, .scheduleBlocked, .idleSuppressed:
            true
        }
    }

    private var primaryText: String {
        switch row.status {
        case .scheduled(let targetDate, _), .snoozed(let targetDate, _):
            targetDate.formatted(date: .omitted, time: .shortened)
        case .paused:
            localizedString("notch.preview.paused")
        case .disabled:
            localizedString("notch.preview.disabled")
        case .idle:
            localizedString("notch.preview.idle")
        case .scheduleBlocked:
            localizedString("notch.preview.schedule_blocked")
        case .idleSuppressed:
            localizedString("notch.preview.idle_suppressed")
        }
    }

    private var secondaryText: String? {
        switch row.status {
        case .scheduled(_, let remainingSeconds):
            scheduledSecondaryText(remainingSeconds: remainingSeconds)
        case .snoozed:
            localizedString("notch.preview.snoozed")
        case .paused(let remainingSeconds):
            remainingSeconds.map { durationText(seconds: $0) }
        case .disabled, .idle, .scheduleBlocked, .idleSuppressed:
            nil
        }
    }

    private func scheduledSecondaryText(remainingSeconds: Int) -> String {
        let duration = durationText(seconds: remainingSeconds)

        switch row.mode {
        case .breakReminder:
            return formattedLocalizedString("notch.preview.after_format", duration)
        case .pomodoro:
            switch row.phase {
            case .focus:
                return formattedLocalizedString("notch.preview.focus_remaining_format", duration)
            case .rest:
                return formattedLocalizedString("notch.preview.rest_remaining_format", duration)
            case nil:
                return formattedLocalizedString("notch.preview.after_format", duration)
            }
        }
    }

    private func durationText(seconds: Int) -> String {
        let safeSeconds = max(seconds, 0)
        guard safeSeconds >= 60 else {
            return localizedString("notch.preview.less_than_minute")
        }

        let minutes = max(Int(ceil(Double(safeSeconds) / 60)), 1)
        return String(format: localizedString("notch.preview.minutes_format"), minutes)
    }

    private func localizedString(_ key: String) -> String {
        NSLocalizedString(key, comment: "")
    }

    private func formattedLocalizedString(_ key: String, _ value: String) -> String {
        String(format: localizedString(key), value)
    }
}

private struct OverlayContentFitSizePreferenceKey: PreferenceKey {
    static var defaultValue = CGSize.zero

    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(
            width: max(value.width, next.width),
            height: max(value.height, next.height)
        )
    }
}

private extension View {
    func overlayContentFitSizeReporter() -> some View {
        background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: OverlayContentFitSizePreferenceKey.self,
                    value: proxy.size
                )
            }
        }
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

            HStack(spacing: 12) {
                PomodoroCountdownProgressView(
                    content: content,
                    remainingSeconds: remaining
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(titleKey)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.62))
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .textCase(.uppercase)

                        if content.isPaused {
                            PomodoroPausedBadge(tint: tint)
                        }
                    }

                    Text(formattedCountdownSeconds(remaining))
                        .font(.system(size: 24, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.92))
                        .lineLimit(1)
                        .minimumScaleFactor(0.86)
                        .contentTransition(.numericText(value: Double(remaining)))
                        .animation(.easeOut(duration: 0.16), value: remaining)
                }
                .frame(minWidth: 82, alignment: .leading)
                .layoutPriority(1)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 16)
            .padding(.top, topInset + 10)
        }
    }

    private var tint: Color {
        PomodoroOverlayStyle.tint(for: content.phase)
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
            size: 34,
            lineWidth: 2.6,
            tint: tint,
            trackTint: .white.opacity(0.13)
        )
        .overlay {
            Image(systemName: symbolName)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(tint)
                .contentTransition(.symbolEffect(.replace))
        }
    }

    private var progress: Double {
        guard content.duration > 0 else { return 0 }
        return clampedProgress((content.duration - TimeInterval(remainingSeconds)) / content.duration)
    }

    private var tint: Color {
        PomodoroOverlayStyle.tint(for: content.phase)
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

private struct PomodoroPausedBadge: View {
    let tint: Color

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "pause.fill")
                .font(.system(size: 7, weight: .bold))

            Text("pomodoro.paused_label")
                .font(.system(size: 9, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .foregroundStyle(tint.opacity(0.9))
        .padding(.horizontal, 5)
        .padding(.vertical, 1.5)
        .background(
            Capsule()
                .fill(tint.opacity(0.12))
        )
        .overlay(
            Capsule()
                .stroke(tint.opacity(0.2), lineWidth: 0.5)
        )
    }
}

private struct PomodoroReminderContentView: View {
    let content: PomodoroReminderContent
    let reminderStartDate: Date
    let reminderDuration: TimeInterval
    let topInset: CGFloat
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            PomodoroReminderTimingView(
                content: content,
                reminderStartDate: reminderStartDate,
                reminderDuration: reminderDuration
            )
            .layoutPriority(1)

            Spacer(minLength: 6)

            Button(action: onDismiss) {
                Text(actionKey)
                    .lineLimit(1)
                    .minimumScaleFactor(0.68)
            }
            .controlSize(.small)
            .buttonStyle(.bordered)
            .tint(actionTint)
            .fixedSize(horizontal: true, vertical: false)
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

    private var actionTint: Color {
        PomodoroOverlayStyle.tint(for: content.kind)
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
            .frame(maxWidth: .infinity, alignment: .leading)
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
                trackTint: .white.opacity(0.14)
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
        PomodoroOverlayStyle.tint(for: kind)
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

private enum PomodoroOverlayStyle {
    static func tint(for phase: PomodoroPhase) -> Color {
        switch phase {
        case .focus:
            Color(red: 0.68, green: 0.80, blue: 1.0)
        case .rest:
            Color(red: 0.48, green: 0.86, blue: 0.62)
        }
    }

    static func tint(for kind: PomodoroReminderContent.Kind) -> Color {
        switch kind {
        case .sessionStarted:
            tint(for: .focus)
        case .focusCompleted, .breakCompleted:
            tint(for: .rest)
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
    let blurRadius: CGFloat

    func body(content: Content) -> some View {
        content
            .opacity(opacity)
            .scaleEffect(scale, anchor: .top)
            .offset(y: offsetY)
            .blur(radius: blurRadius)
    }
}

private extension AnyTransition {
    static let notchOverlayInsertion = asymmetric(
        insertion: .modifier(
            active: NotchOverlayTransitionModifier(opacity: 0, scale: 0.94, offsetY: -16, blurRadius: 8),
            identity: NotchOverlayTransitionModifier(opacity: 1, scale: 1, offsetY: 0, blurRadius: 0)
        ),
        removal: .modifier(
            active: NotchOverlayTransitionModifier(opacity: 0, scale: 0.97, offsetY: -10, blurRadius: 5),
            identity: NotchOverlayTransitionModifier(opacity: 1, scale: 1, offsetY: 0, blurRadius: 0)
        )
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
        notchHubStore: NotchHubStore(
            defaults: settings.defaults,
            dailyScheduleStore: DailyScheduleStore(defaults: settings.defaults)
        ),
        overlayMetrics: overlayMetrics,
        onOpenDashboard: {},
        onOpenSettings: {}
    )
        .frame(width: 380, height: 160)
        .background(.gray)
        .onAppear {
            engine.send(.manualTrigger)
            engine.send(.hoverChanged(true))
        }
}
