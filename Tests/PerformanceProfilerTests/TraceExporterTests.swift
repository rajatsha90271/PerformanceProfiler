//
//  TraceExporterTests.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 19/06/2026.
//

import XCTest
@testable import PerformanceProfiler
import ProfilerCore

final class TraceExporterTests: XCTestCase {

    private var sampleTrace: Trace {
        Trace(
            id: UUID(),
            startTime: Date(timeIntervalSince1970: 0),
            endTime:   Date(timeIntervalSince1970: 10),
            deviceInfo: Trace.DeviceInfo(
                model: "iPhone16,2",
                osVersion: "iOS 18.0",
                processorCount: 6,
                physicalMemoryBytes: 8_589_934_592
            ),
            samples: [
                Trace.Sample(timestamp: 0,   cpuUsage: 0.1, memoryBytes: 50_000_000, fps: 60, thermalState: 0),
                Trace.Sample(timestamp: 0.1, cpuUsage: 0.5, memoryBytes: 55_000_000, fps: 59, thermalState: 1),
            ]
        )
    }

    func test_jsonExportIsValidJSON() throws {
        let data = try TraceExporter.exportJSON(sampleTrace)
        XCTAssertNoThrow(try JSONSerialization.jsonObject(with: data))
    }

    func test_jsonExportRoundTrips() throws {
        let trace = sampleTrace
        let data  = try TraceExporter.exportJSON(trace)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Trace.self, from: data)
        XCTAssertEqual(decoded.id, trace.id)
        XCTAssertEqual(decoded.samples.count, trace.samples.count)
        XCTAssertEqual(decoded.samples[0].cpuUsage, trace.samples[0].cpuUsage, accuracy: 0.001)
    }

    func test_exportToTempFileCreatesFile() throws {
        let url = try TraceExporter.exportToTempFile(sampleTrace)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        try? FileManager.default.removeItem(at: url)
    }

    func test_chromeTraceExportIsValidJSON() throws {
        let data = try TraceExporter.exportChromeTrace(sampleTrace)
        let obj  = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertNotNil(obj?["traceEvents"])
    }

    func test_traceStatisticsAreCorrect() {
        let trace = sampleTrace
        XCTAssertEqual(trace.averageCPU,       0.3,  accuracy: 0.001)
        XCTAssertEqual(trace.peakCPU,          0.5,  accuracy: 0.001)
        XCTAssertEqual(trace.peakMemoryBytes,  55_000_000)
        XCTAssertEqual(trace.averageFPS,       59.5, accuracy: 0.001)
    }
}
