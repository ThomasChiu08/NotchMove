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

    private let shapeAnimation = Animation.smooth(duration: 0.24, extraBounce: 0)
    private let contentAnimation = Animation.smooth(duration: 0.2, extraBounce: 0)

    var body: some View {
        ZStack(alignment: .top) {
            NotchShape(cornerRadius: cornerRadius)
                .fill(.black)
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

    private var reminderContent: some View {
        ReminderContentView(
            reminderStartDate: reminderEngine.overlayState.reminderStartDate,
            reminderDuration: reminderEngine.overlayState.reminderDuration,
            topInset: overlayMetrics.topInset
        ) {
            reminderEngine.send(.completeBreak)
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
                    .shadow(color: .green.opacity(0.32), radius: 2)
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

private struct ReminderContentView: View {
    let reminderStartDate: Date
    let reminderDuration: TimeInterval
    let topInset: CGFloat
    let onCompleteBreak: () -> Void

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

            Button(action: onCompleteBreak) {
                Text("stand_and_move")
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .controlSize(.small)
            .buttonStyle(.borderedProminent)
            .tint(.green)
        }
        .padding(.horizontal, 14)
        .padding(.top, topInset + 4)
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

            ProgressRingView(progress: progress, size: 36, lineWidth: 3)
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
