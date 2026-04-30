//
//  ProgressRingView.swift
//  NotchMove
//
//  Created by Codex on 4/22/26.
//

import SwiftUI

struct ProgressRingView: View {
    let progress: Double

    var size: CGFloat = 44
    var lineWidth: CGFloat = 4
    var tint: Color = .green
    var trackTint: Color = .white.opacity(0.14)

    private var clampedProgress: CGFloat {
        let safeProgress = progress.isFinite ? progress : 0
        return CGFloat(min(max(safeProgress, 0), 1))
    }

    private var strokeStyle: StrokeStyle {
        StrokeStyle(lineWidth: lineWidth, lineCap: .round)
    }

    private var ringGradient: AngularGradient {
        AngularGradient(
            colors: [tint.opacity(0.82), tint, tint.opacity(0.96)],
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    private var ringShape: some Shape {
        Circle().inset(by: lineWidth / 2)
    }

    var body: some View {
        ZStack {
            ringShape
                .stroke(trackTint, style: strokeStyle)

            progressLayer
        }
        .frame(width: size, height: size)
    }

    @ViewBuilder
    private var progressLayer: some View {
        if clampedProgress >= 1 {
            ringShape
                .stroke(ringGradient, style: strokeStyle)
                .shadow(color: tint.opacity(0.18), radius: 1.5)
        } else if clampedProgress > 0 {
            ringShape
                .trim(from: 0, to: clampedProgress)
                .stroke(ringGradient, style: strokeStyle)
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.18), radius: 1.5)
        }
    }
}

#Preview {
    ZStack {
        Color.black

        ProgressRingView(progress: 0.78, size: 52)
            .overlay {
                Image(systemName: "figure.flexibility")
                    .font(.title3)
                    .foregroundStyle(.white)
            }
    }
    .frame(width: 120, height: 120)
}
