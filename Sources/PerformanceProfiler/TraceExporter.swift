//
//  TraceExporter.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 25/05/2026.
//

import Foundation
import ProfilerCore

/// Serialises a `Trace` to various formats for offline analysis.
public enum TraceExporter {

    // MARK: - JSON

    /// Returns a pretty-printed JSON `Data` blob.
    public static func exportJSON(_ trace: Trace, prettyPrinted: Bool = true) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = prettyPrinted ? [.prettyPrinted, .sortedKeys] : []
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(trace)
    }

    // MARK: - File

    /// Writes JSON to a file in the app's temporary directory and returns the URL.
    /// The file name includes the session ID for uniqueness.
    public static func exportToTempFile(_ trace: Trace) throws -> URL {
        let data = try exportJSON(trace)
        let url  = FileManager.default.temporaryDirectory
            .appendingPathComponent("trace-\(trace.id.uuidString).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Chrome Trace Format (compatible with chrome://tracing and Perfetto)

    /// Exports the trace in Chrome's JSON trace event format so it can be loaded
    /// into `chrome://tracing` or Perfetto UI for flame-chart visualisation.
    public static func exportChromeTrace(_ trace: Trace) throws -> Data {
        var events: [[String: Any]] = []

        for sample in trace.samples {
            let tsUs = Int64(sample.timestamp * 1_000_000)   // microseconds

            events.append([
                "name": "CPU",
                "ph":   "C",      // counter event
                "ts":   tsUs,
                "pid":  1,
                "args": ["usage": Double(sample.cpuUsage)]
            ])

            events.append([
                "name": "Memory",
                "ph":   "C",
                "ts":   tsUs,
                "pid":  1,
                "args": ["bytes": sample.memoryBytes]
            ])

            if sample.fps > 0 {
                events.append([
                    "name": "FPS",
                    "ph":   "C",
                    "ts":   tsUs,
                    "pid":  1,
                    "args": ["fps": Double(sample.fps)]
                ])
            }
        }

        let root: [String: Any] = [
            "traceEvents":  events,
            "displayTimeUnit": "ms",
            "metadata": [
                "device":    trace.deviceInfo.model,
                "osVersion": trace.deviceInfo.osVersion,
                "sessionID": trace.id.uuidString,
            ]
        ]

        return try JSONSerialization.data(withJSONObject: root, options: .prettyPrinted)
    }
}
