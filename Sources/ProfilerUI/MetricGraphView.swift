//
//  MetricGraphView.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 10/06/2026.
//

import SwiftUI

/// A compact sparkline graph for a rolling history of float values.
public struct MetricGraphView: View {
    public let values: [Float]
    public let color: Color
    public let range: ClosedRange<Float>?     // nil → auto-scale to data

    public init(values: [Float], color: Color, range: ClosedRange<Float>? = nil) {
        self.values = values
        self.color  = color
        self.range  = range
    }

    public var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height

            if values.count > 1 {
                let lo  = range?.lowerBound ?? (values.min() ?? 0)
                let hi  = range?.upperBound ?? max(values.max() ?? 1, lo + 0.001)
                let span = hi - lo

                Path { path in
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) / CGFloat(values.count - 1) * w
                        let y = h - CGFloat((v - lo) / span) * h
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else       { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineJoin: .round))

                // Filled area under the curve
                Path { path in
                    for (i, v) in values.enumerated() {
                        let x = CGFloat(i) / CGFloat(values.count - 1) * w
                        let y = h - CGFloat((v - lo) / span) * h
                        if i == 0 { path.move(to: CGPoint(x: x, y: h)); path.addLine(to: CGPoint(x: x, y: y)) }
                        else       { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    path.addLine(to: CGPoint(x: w, y: h))
                    path.closeSubpath()
                }
                .fill(color.opacity(0.15))
            }
        }
    }
}
