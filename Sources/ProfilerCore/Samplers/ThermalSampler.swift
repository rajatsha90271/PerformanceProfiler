//
//  ThermalSampler.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 05/06/2026.
//

import Foundation

/// Reads the device's thermal state from `ProcessInfo`.
/// Can also subscribe to `NSProcessInfoThermalStateDidChangeNotification`
/// for push-style updates; this sampler uses polling to stay consistent
/// with the unified sampling cadence.
public final class ThermalSampler {
    public init() {}

    public func sample() -> MetricSample.ThermalState {
        switch ProcessInfo.processInfo.thermalState {
        case .nominal:  return .nominal
        case .fair:     return .fair
        case .serious:  return .serious
        case .critical: return .critical
        @unknown default: return .nominal
        }
    }
}
