//
//  PerformanceProfiler.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 01/06/2026.
//

import Foundation
import Combine
import ProfilerCore

/// The main entry point for the Performance Profiler SDK.
///
/// ```swift
/// let profiler = PerformanceProfiler()
/// profiler.start()
///
/// // Live values via Combine
/// profiler.samplePublisher
///     .receive(on: DispatchQueue.main)
///     .sink { sample in updateUI(sample) }
///     .store(in: &cancellables)
///
/// // Export a trace when done
/// let trace = profiler.stop()
/// let data  = try TraceExporter.exportJSON(trace)
/// ```
public final class PerformanceProfiler: @unchecked Sendable {

    // MARK: - Public

    public let configuration: ProfilerConfiguration

    /// Fires every `configuration.samplingInterval` seconds.
    /// Values are delivered on the internal sampler queue; receive on `.main` for UI.
    public var samplePublisher: AnyPublisher<MetricSample, Never> {
        orchestrator.samplePublisher.eraseToAnyPublisher()
    }

    public private(set) var isRunning = false

    // MARK: - Private

    private let orchestrator: SamplerOrchestrator

    // MARK: - Init

    public init(configuration: ProfilerConfiguration = .init()) {
        self.configuration = configuration
        self.orchestrator  = SamplerOrchestrator()
    }

    // MARK: - Lifecycle

    /// Begins sampling. Safe to call multiple times — subsequent calls are no-ops.
    @MainActor
    public func start() {
        guard !isRunning else { return }
        isRunning = true
        if configuration.trackFPS {
            orchestrator.fpsSampler.start()
        }
        orchestrator.start(interval: configuration.samplingInterval)
    }

    /// Stops sampling and returns the completed `Trace`.
    @MainActor
    @discardableResult
    public func stop() -> Trace {
        guard isRunning else { return orchestrator.traceStore.snapshot() }
        isRunning = false
        orchestrator.stop()
        if configuration.trackFPS {
            orchestrator.fpsSampler.stop()
        }
        return orchestrator.traceStore.snapshot()
    }

    /// Exports a snapshot of all samples collected so far without stopping.
    public func currentTrace() -> Trace {
        orchestrator.traceStore.snapshot()
    }

    /// Clears all accumulated samples and resets the session.
    @MainActor
    public func reset() {
        let wasRunning = isRunning
        if wasRunning { _ = stop() }
        orchestrator.traceStore.reset()
        if wasRunning { start() }
    }
}
