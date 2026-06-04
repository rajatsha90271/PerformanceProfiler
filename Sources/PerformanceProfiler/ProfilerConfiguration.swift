//
//  ProfilerConfiguration.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 02/06/2026.
//

import Foundation

/// Controls what the profiler measures and how often.
public struct ProfilerConfiguration: Sendable {

    /// How frequently all samplers fire. Lower values = higher resolution + more CPU overhead.
    /// Default: 100 ms (10 Hz), suitable for live overlays.
    public var samplingInterval: TimeInterval

    /// Maximum samples retained in the ring buffer per sampler.
    /// Must be a power of 2. Excess samples are dropped (oldest first).
    public var ringBufferCapacity: Int

    /// When `true`, the profiler also tracks FPS via `CADisplayLink` on the main thread.
    public var trackFPS: Bool

    /// When `true`, thermal state changes are sampled alongside CPU/memory.
    public var trackThermalState: Bool

    public init(
        samplingInterval: TimeInterval = 0.1,
        ringBufferCapacity: Int = 1024,
        trackFPS: Bool = true,
        trackThermalState: Bool = true
    ) {
        precondition(samplingInterval > 0)
        precondition(ringBufferCapacity.isPowerOfTwo && ringBufferCapacity > 1)
        self.samplingInterval    = samplingInterval
        self.ringBufferCapacity  = ringBufferCapacity
        self.trackFPS            = trackFPS
        self.trackThermalState   = trackThermalState
    }

    /// Convenience preset for release-build background monitoring (low overhead).
    public static let lightweight = ProfilerConfiguration(
        samplingInterval: 1.0,
        ringBufferCapacity: 256,
        trackFPS: false,
        trackThermalState: true
    )

    /// Convenience preset for debugging frame drops.
    public static let highFrequency = ProfilerConfiguration(
        samplingInterval: 0.033,   // ~30 Hz
        ringBufferCapacity: 2048,
        trackFPS: true,
        trackThermalState: true
    )
}

// Re-export helper so callers don't need to import ProfilerCore.
extension Int {
    var isPowerOfTwo: Bool { self > 0 && (self & (self - 1)) == 0 }
}
