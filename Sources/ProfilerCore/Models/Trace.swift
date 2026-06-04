//
//  Trace.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 23/03/2026.
//

import Foundation

/// A complete profiling session — produced by TraceStore and exported by TraceExporter.
public struct Trace: Codable, Sendable {
    public let id: UUID
    public let startTime: Date
    public let endTime: Date
    public let deviceInfo: DeviceInfo
    public let samples: [Sample]

    public struct Sample: Codable, Sendable {
        public let timestamp: Double
        public let cpuUsage: Float
        public let memoryBytes: UInt64
        public let fps: Float
        public let thermalState: UInt8
    }

    public struct DeviceInfo: Codable, Sendable {
        public let model: String
        public let osVersion: String
        public let processorCount: Int
        public let physicalMemoryBytes: UInt64
    }
}

extension Trace {
    /// Duration of the profiling session in seconds.
    public var duration: TimeInterval { endTime.timeIntervalSince(startTime) }

    public var averageCPU: Float {
        guard !samples.isEmpty else { return 0 }
        return samples.map(\.cpuUsage).reduce(0, +) / Float(samples.count)
    }

    public var peakCPU: Float { samples.map(\.cpuUsage).max() ?? 0 }
    public var peakMemoryBytes: UInt64 { samples.map(\.memoryBytes).max() ?? 0 }

    public var averageFPS: Float {
        let fpsSamples = samples.filter { $0.fps > 0 }
        guard !fpsSamples.isEmpty else { return 0 }
        return fpsSamples.map(\.fps).reduce(0, +) / Float(fpsSamples.count)
    }
}
