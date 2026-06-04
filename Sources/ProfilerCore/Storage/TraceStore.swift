//
//  TraceStore.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 05/03/2026.
//

import Foundation

/// Accumulates `MetricSample` values during a profiling session and produces
/// a `Trace` on demand. Thread-safe: `record` is called from the sampler queue,
/// `snapshot` from any thread.
public final class TraceStore: @unchecked Sendable {
    private let lock = NSLock()
    private var samples: [MetricSample] = []
    private let startTime: Date
    private let sessionID = UUID()

    public init() {
        startTime = Date()
        samples.reserveCapacity(3_600)  // ~1 hour at 1 Hz
    }

    // MARK: - Recording (producer side)

    public func record(_ sample: MetricSample) {
        lock.withLock { samples.append(sample) }
    }

    // MARK: - Snapshot (consumer side)

    /// Produces an immutable `Trace` from all samples collected so far.
    public func snapshot() -> Trace {
        let captured = lock.withLock { samples }
        return Trace(
            id: sessionID,
            startTime: startTime,
            endTime: Date(),
            deviceInfo: DeviceInfo.current,
            samples: captured.map { s in
                Trace.Sample(
                    timestamp: s.timestamp,
                    cpuUsage: s.cpuUsage,
                    memoryBytes: s.memoryBytes,
                    fps: s.fps,
                    thermalState: s.thermalState.rawValue
                )
            }
        )
    }

    /// Clears all accumulated samples.
    public func reset() {
        lock.withLock { samples.removeAll(keepingCapacity: true) }
    }
}

// MARK: - Device info

private struct DeviceInfo {
    static var current: Trace.DeviceInfo {
        let info = ProcessInfo.processInfo
        return Trace.DeviceInfo(
            model: Self.modelIdentifier,
            osVersion: info.operatingSystemVersionString,
            processorCount: info.processorCount,
            physicalMemoryBytes: info.physicalMemory
        )
    }

    private static var modelIdentifier: String {
        var sysinfo = utsname()
        uname(&sysinfo)
        return withUnsafeBytes(of: &sysinfo.machine) { ptr in
            String(cString: ptr.bindMemory(to: CChar.self).baseAddress!)
        }
    }
}
