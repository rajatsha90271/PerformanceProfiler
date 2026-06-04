//
//  SamplerOrchestrator.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 15/04/2026.
//

import Foundation
import Combine
import QuartzCore

/// Coordinates all samplers, fires on a high-priority background queue, and
/// publishes a live `MetricSample` stream via Combine.
public final class SamplerOrchestrator: @unchecked Sendable {

    // MARK: - Public output

    /// Emits one value per sampling interval. Always delivered on the sampler queue —
    /// use `.receive(on: DispatchQueue.main)` before driving UI.
    public let samplePublisher = PassthroughSubject<MetricSample, Never>()
    public let traceStore = TraceStore()

    // MARK: - Private

    private let queue = DispatchQueue(
        label: "com.performanceprofiler.sampler",
        qos: .userInteractive,
        autoreleaseFrequency: .workItem
    )
    private var timer: DispatchSourceTimer?
    private let cpuSampler     = CPUSampler()
    private let memorySampler  = MemorySampler()
    private let thermalSampler = ThermalSampler()
    // FPS sampler must start on main thread; its reads are atomic.
    public  let fpsSampler     = FPSSampler()

    public init() {}

    deinit { stop() }

    // MARK: - Lifecycle

    /// Starts sampling at the given interval. Call `fpsSampler.start()` on the
    /// main thread before or after this — `SamplerOrchestrator` does not call it
    /// automatically to keep the main-thread requirement explicit at the call site.
    public func start(interval: TimeInterval = 0.1) {
        guard timer == nil else { return }

        let source = DispatchSource.makeTimerSource(queue: queue)
        source.schedule(
            deadline: .now(),
            repeating: interval,
            leeway: .milliseconds(5)    // tight leeway for profiler accuracy
        )
        source.setEventHandler { [weak self] in self?.collectSample() }
        source.resume()
        timer = source
    }

    public func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Private

    private func collectSample() {
        let sample = MetricSample(
            timestamp: CACurrentMediaTime(),
            cpuUsage: cpuSampler.sample(),
            memoryBytes: memorySampler.sample(),
            fps: fpsSampler.currentFPS,
            thermalState: thermalSampler.sample()
        )
        traceStore.record(sample)
        samplePublisher.send(sample)
    }
}
