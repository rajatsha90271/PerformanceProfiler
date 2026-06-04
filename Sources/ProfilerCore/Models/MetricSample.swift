//
//  MetricSample.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 02/06/2026.
//

import Foundation

/// A single point-in-time snapshot from all active samplers.
public struct MetricSample: Sendable {
    public let timestamp: Double        // seconds since process launch (CACurrentMediaTime)
    public let cpuUsage: Float          // sum across all threads; can exceed 1.0 on multi-core
    public let memoryBytes: UInt64      // physical footprint (what Activity Monitor shows)
    public let fps: Float               // frames per second, 0–120
    public let thermalState: ThermalState

    public enum ThermalState: UInt8, Sendable, Codable, CustomStringConvertible {
        case nominal, fair, serious, critical

        public var description: String {
            switch self {
            case .nominal:  return "Nominal"
            case .fair:     return "Fair"
            case .serious:  return "Serious"
            case .critical: return "Critical"
            }
        }

        /// A color name suitable for UI tinting (maps to SwiftUI Color names).
        public var severityLabel: String {
            switch self {
            case .nominal:  return "green"
            case .fair:     return "yellow"
            case .serious:  return "orange"
            case .critical: return "red"
            }
        }
    }
}

extension MetricSample {
    /// Megabytes, rounded to one decimal.
    public var memoryMB: Float { Float(memoryBytes) / 1_048_576 }
}
