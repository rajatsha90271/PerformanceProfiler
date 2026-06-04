//
//  ProfilerOverlayView.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 10/06/2026.
//

import SwiftUI
import PerformanceProfiler

/// A draggable floating overlay that displays live CPU, memory, FPS and thermal
/// metrics. Drop it anywhere in your SwiftUI hierarchy — it positions itself via
/// `.overlay(alignment: .topLeading)` and handles its own drag gesture.
///
/// ```swift
/// ContentView()
///     .overlay(alignment: .topLeading) {
///         ProfilerOverlayView(profiler: profiler)
///             .padding(12)
///     }
/// ```
public struct ProfilerOverlayView: View {

    @StateObject private var viewModel: ProfilerViewModel
    @State private var isExpanded = false
    @State private var dragOffset  = CGSize.zero

    public init(profiler: PerformanceProfiler) {
        _viewModel = StateObject(wrappedValue: ProfilerViewModel(profiler: profiler))
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow

            if isExpanded {
                Divider().padding(.vertical, 6)
                expandedMetrics
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(.white.opacity(0.18), lineWidth: 0.5)
        )
        .shadow(color: .black.opacity(0.25), radius: 8, y: 4)
        .offset(dragOffset)
        .gesture(dragGesture)
        .animation(.spring(response: 0.3, dampingFraction: 0.75), value: isExpanded)
    }

    // MARK: - Sub-views

    private var headerRow: some View {
        HStack(spacing: 8) {
            Circle()
                .fill(thermalColor)
                .frame(width: 8, height: 8)

            Text("Profiler")
                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                .foregroundStyle(.secondary)

            Spacer(minLength: 12)

            Text(viewModel.cpuText)
                .metricLabel(color: .cyan)

            Text(viewModel.fpsText)
                .metricLabel(color: .green)

            Button {
                withAnimation { isExpanded.toggle() }
            } label: {
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .frame(height: 24)
    }

    private var expandedMetrics: some View {
        VStack(alignment: .leading, spacing: 10) {
            metricRow(
                label: "CPU",
                value: viewModel.cpuText,
                graph: viewModel.cpuHistory,
                graphColor: .cyan,
                graphRange: 0...2.0     // 0–200% (two cores)
            )

            metricRow(
                label: "MEM",
                value: viewModel.memoryText,
                graph: viewModel.memoryHistory,
                graphColor: .purple,
                graphRange: nil
            )

            metricRow(
                label: "FPS",
                value: viewModel.fpsText,
                graph: viewModel.fpsHistory,
                graphColor: .green,
                graphRange: 0...120
            )

            HStack {
                Text("THERMAL")
                    .labelStyle()
                Spacer()
                Text(viewModel.thermalText)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundColor(thermalColor)
            }
        }
        .frame(width: 220)
    }

    private func metricRow(
        label: String,
        value: String,
        graph: [Float],
        graphColor: Color,
        graphRange: ClosedRange<Float>?
    ) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).labelStyle()
                Spacer()
                Text(value)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(.primary)
            }
            MetricGraphView(values: graph, color: graphColor, range: graphRange)
                .frame(height: 32)
        }
    }

    // MARK: - Helpers

    private var thermalColor: Color {
        switch viewModel.thermalColor {
        case "yellow": return .yellow
        case "orange": return .orange
        case "red":    return .red
        default:       return .green
        }
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { v in dragOffset = v.translation }
            .onEnded   { _ in }     // keep where dropped; reset to zero to snap back
    }
}

// MARK: - Text modifiers

private extension Text {
    func metricLabel(color: Color) -> some View {
        self
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundColor(color)
    }

    func labelStyle() -> some View {
        self
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(.tertiary)
            .tracking(0.5)
    }
}
