//
//  NotchView.swift
//  NotchMove
//
//  Created by Thomas Chiu on 4/16/26.
//

import SwiftUI

struct NotchView: View {
    let viewModel: NotchViewModel

    var body: some View {
        ZStack {
            NotchShape(cornerRadius: cornerRadius)
                .fill(.black)

            content
                .clipped()
        }
        .onHover { hovering in
            if hovering {
                viewModel.hover()
            } else {
                viewModel.unhover()
            }
        }
        .animation(.spring(duration: 0.35), value: viewModel.state)
    }

    private var cornerRadius: CGFloat {
        switch viewModel.state {
        case .dormant, .dismissed: 12
        case .hovering: 16
        case .reminding: 18
        }
    }

    @ViewBuilder
    private var content: some View {
        switch viewModel.state {
        case .dormant, .dismissed:
            EmptyView()
        case .hovering:
            hoverPreview
                .transition(.opacity)
        case .reminding:
            reminderContent
                .transition(.opacity)
        }
    }

    private var hoverPreview: some View {
        HStack(spacing: 8) {
            Image(systemName: "figure.stand")
                .foregroundStyle(.white.opacity(0.5))
            Text("Next reminder soon")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
        }
        .padding(.top, viewModel.topInset + 4)
    }

    private var reminderContent: some View {
        TimelineView(.animation) { context in
            let elapsed = context.date.timeIntervalSince(viewModel.reminderStartDate)
            let progress = min(max(elapsed / viewModel.reminderDuration, 0), 1)

            HStack(spacing: 16) {
                progressRing(progress: progress)
                labels(progress: progress)
                Spacer()
                dismissButton
            }
            .padding(.horizontal, 20)
            .padding(.top, viewModel.topInset + 4)
        }
    }

    private func progressRing(progress: Double) -> some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.15), lineWidth: 3)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(.green, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Image(systemName: stretchSymbol(for: progress))
                .font(.title3)
                .foregroundStyle(.white)
                .contentTransition(.symbolEffect(.replace))
        }
        .frame(width: 44, height: 44)
    }

    private func labels(progress: Double) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("Time to stretch!")
                .font(.system(.subheadline, weight: .semibold))
                .foregroundStyle(.white)

            let remaining = Int(ceil(viewModel.reminderDuration * (1 - progress)))
            Text("\(remaining)s")
                .font(.caption)
                .foregroundStyle(.white.opacity(0.6))
                .monospacedDigit()
        }
    }

    private var dismissButton: some View {
        Button("Stand & Move") {
            viewModel.dismiss()
        }
        .controlSize(.small)
        .buttonStyle(.borderedProminent)
        .tint(.green)
    }

    private func stretchSymbol(for progress: Double) -> String {
        switch progress {
        case ..<0.33: "figure.stand"
        case 0.33..<0.66: "figure.flexibility"
        default: "figure.walk"
        }
    }
}

#Preview {
    let vm = NotchViewModel()
    NotchView(viewModel: vm)
        .frame(width: 380, height: 160)
        .background(.gray)
        .onAppear { vm.triggerReminder() }
}
