//
//  NotchView.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import SwiftUI

struct NotchView: View {
    let reminderEngine: ReminderEngine
    let overlayMetrics: NotchOverlayMetrics

    private let shapeAnimation = Animation.smooth(duration: 0.2, extraBounce: 0)
    private let contentAnimation = Animation.smooth(duration: 0.18, extraBounce: 0)

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(cornerRadius: cornerRadius)
                .fill(Color(red: 0.02, green: 0.02, blue: 0.02))
                .animation(shapeAnimation, value: reminderEngine.overlayState.presentation)

            contentLayer
                .clipped()
        }
        .onHover { hovering in
            reminderEngine.send(.hoverChanged(hovering))
        }
    }

    private var cornerRadius: CGFloat {
        switch reminderEngine.overlayState.presentation {
        case .hidden, .reminderPending, .dismissAnimating: 10
        case .hoverPreview: 14
        case .presenting: 16
        }
    }

    private var contentLayer: some View {
        ZStack(alignment: .top) {
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .animation(contentAnimation, value: reminderEngine.overlayState.presentation)
    }

    @ViewBuilder
    private var content: some View {
        switch reminderEngine.overlayState.presentation {
        case .hidden, .dismissAnimating:
            EmptyView()
        case .reminderPending:
            reminderPendingIndicator
                .transition(.opacity)
        case .hoverPreview:
            hoverPreview
                .transition(.notchOverlayInsertion)
        case .presenting:
            reminderContent
                .transition(.notchOverlayInsertion)
        }
    }

    private var hoverPreview: some View {
        HoverPreviewView(topInset: overlayMetrics.topInset)
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
            } onDismiss: {
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
                    .frame(width: 42 + 24 * CGFloat(progress), height: 2)
                    .padding(.bottom, 4)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .allowsHitTesting(false)
        }
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

private struct BreakReminderContentView: View {
    let reminderStartDate: Date
    let reminderDuration: TimeInterval
    let topInset: CGFloat
    let onCompleteBreak: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ReminderProgressView(
                reminderStartDate: reminderStartDate,
                reminderDuration: reminderDuration
            )

            VStack(alignment: .leading, spacing: 1) {
                Text("time_to_stretch")
                    .font(.system(.caption, weight: .semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                ReminderCountdownLabel(
                    reminderStartDate: reminderStartDate,
                    reminderDuration: reminderDuration
                )
            }

            Spacer(minLength: 8)

            Button(action: onDismiss) {
                Text("notch.later")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
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

private struct ScheduleReminderContentView: View {
    let content: ReminderEngine.ScheduleReminderContent
    let reminderStartDate: Date
    let reminderDuration: TimeInterval
    let topInset: CGFloat
    let onComplete: () -> Void
    let onSnooze: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            ReminderProgressView(
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

private struct ReminderProgressView: View {
    let reminderStartDate: Date
    let reminderDuration: TimeInterval

    var body: some View {
        TimelineView(.animation) { context in
            let progress = reminderProgress(
                at: context.date,
                reminderStartDate: reminderStartDate,
                reminderDuration: reminderDuration
            )

            ProgressRingView(progress: progress, size: 32, lineWidth: 2.5)
                .overlay {
                    Image(systemName: stretchSymbol(for: progress))
                        .font(.caption)
                        .foregroundStyle(.white)
                        .contentTransition(.symbolEffect(.replace))
                }
        }
    }
}

private struct ReminderCountdownLabel: View {
    let reminderStartDate: Date
    let reminderDuration: TimeInterval

    var body: some View {
        TimelineView(.animation) { context in
            Text("\(remainingSeconds(at: context.date, reminderStartDate: reminderStartDate, reminderDuration: reminderDuration))s")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
        }
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
            active: NotchOverlayTransitionModifier(opacity: 0, scale: 0.985, offsetY: -4),
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
    func playReminderSound() {}
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

    NotchView(reminderEngine: engine, overlayMetrics: overlayMetrics)
        .frame(width: 380, height: 160)
        .background(.gray)
        .onAppear {
            engine.send(.manualTrigger)
            engine.send(.hoverChanged(true))
        }
}
