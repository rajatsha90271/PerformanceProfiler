//
//  ProfilerViewModel.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 10/06/2026.
//

import Foundation
import Combine
import PerformanceProfiler
import ProfilerCore

/// Drives the overlay UI. Receives raw `MetricSample` values from the profiler
/// and maintains rolling history arrays for sparkline graphs.
@MainActor
public final class ProfilerViewModel: ObservableObject {

    // MARK: - Published state

    @Published public private(set) var latest: MetricSample?

    @Published public private(set) var cpuHistory:    [Float] = []
    @Published public private(set) var memoryHistory: [Float] = []   // in MB
    @Published public private(set) var fpsHistory:    [Float] = []

    // MARK: - Configuration

    /// Number of samples to retain for sparklines.
    public let historyLength: Int

    // MARK: - Private

    private let profiler: PerformanceProfiler
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init(profiler: PerformanceProfiler, historyLength: Int = 60) {
        self.profiler      = profiler
        self.historyLength = historyLength

        profiler.samplePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] sample in self?.ingest(sample) }
            .store(in: &cancellables)
    }

    // MARK: - Private

    private func ingest(_ sample: MetricSample) {
        latest = sample
        append(sample.cpuUsage,  to: &cpuHistory)
        append(sample.memoryMB,  to: &memoryHistory)
        append(sample.fps,       to: &fpsHistory)
    }

    private func append(_ value: Float, to history: inout [Float]) {
        history.append(value)
        if history.count > historyLength {
            history.removeFirst(history.count - historyLength)
        }
    }

    // MARK: - Formatted values for display

    public var cpuText: String {
        guard let v = latest?.cpuUsage else { return "—" }
        return String(format: "%.1f%%", v * 100)
    }

    public var memoryText: String {
        guard let v = latest?.memoryMB else { return "—" }
        return v >= 1024
            ? String(format: "%.2f GB", v / 1024)
            : String(format: "%.1f MB", v)
    }

    public var fpsText: String {
        guard let v = latest?.fps, v > 0 else { return "—" }
        return String(format: "%.0f fps", v)
    }

    public var thermalText: String {
        latest?.thermalState.description ?? "—"
    }

    public var thermalColor: String {
        latest?.thermalState.severityLabel ?? "green"
    }
}
