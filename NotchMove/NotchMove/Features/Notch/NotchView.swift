//
//  NotchView.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import SwiftUI

struct NotchView: View {
    let reminderEngine: ReminderEngine
    let topInset: CGFloat

    var body: some View {
        ZStack {
            NotchShape(cornerRadius: cornerRadius)
                .fill(.black)

            content
                .clipped()
        }
        .onHover { hovering in
            reminderEngine.send(.hoverChanged(hovering))
        }
        .animation(.spring(duration: 0.35), value: reminderEngine.state.presentation)
    }

    private var cornerRadius: CGFloat {
        switch reminderEngine.state.presentation {
        case .hidden, .dismissAnimating: 12
        case .hoverPreview: 16
        case .presenting: 18
        }
    }

    @ViewBuilder
    private var content: some View {
        switch reminderEngine.state.presentation {
        case .hidden, .dismissAnimating:
            EmptyView()
        case .hoverPreview:
            hoverPreview
                .transition(.opacity)
        case .presenting:
            reminderContent
                .transition(.opacity)
        }
    }

    private var hoverPreview: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.stand")
                .foregroundStyle(.white.opacity(0.5))
            Text("next_reminder_soon")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, topInset + 4)
    }

    private var reminderContent: some View {
        TimelineView(.animation) { context in
            let progress = reminderProgress(at: context.date)

            HStack(spacing: 16) {
                progressRing(progress: progress)
                labels(progress: progress)
                Spacer()
                dismissButton
            }
            .padding(.horizontal, 20)
            .padding(.top, topInset + 4)
        }
    }

    private func progressRing(progress: Double) -> some View {
        ProgressRingView(progress: progress, size: 48, lineWidth: 4)
            .overlay {
                Image(systemName: stretchSymbol(for: progress))
                    .font(.title3)
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
    }

    private func labels(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("time_to_stretch")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.white)

            let remaining = Int(ceil(reminderEngine.reminderDuration * (1 - clampedProgress(progress))))
            Text("\(remaining)s")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
        }
    }

    private var dismissButton: some View {
        Button {
            reminderEngine.send(.completeBreak)
        } label: {
            Text("stand_and_move")
        }
        .controlSize(.small)
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }

    private func stretchSymbol(for progress: Double) -> String {
        switch clampedProgress(progress) {
        case ..<0.33: "figure.stand"
        case 0.33..<0.66: "figure.flexibility"
        default: "figure.walk"
        }
    }

    private func reminderProgress(at date: Date) -> Double {
        guard reminderEngine.reminderDuration > 0 else { return 0 }

        let elapsed = date.timeIntervalSince(reminderEngine.state.reminderStartDate)
        return clampedProgress(elapsed / reminderEngine.reminderDuration)
    }

    private func clampedProgress(_ progress: Double) -> Double {
        let safeProgress = progress.isFinite ? progress : 0
        return min(max(safeProgress, 0), 1)
    }
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

    NotchView(reminderEngine: engine, topInset: 38)
        .frame(width: 380, height: 160)
        .background(.gray)
        .onAppear { engine.send(.manualTrigger) }
}
