//
//  TraceStoreTests.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 19/06/2026.
//

import XCTest
@testable import ProfilerCore

final class TraceStoreTests: XCTestCase {

    private func makeSample(ts: Double = 0) -> MetricSample {
        MetricSample(
            timestamp: ts,
            cpuUsage: 0.5,
            memoryBytes: 50_000_000,
            fps: 60,
            thermalState: .nominal
        )
    }

    func test_emptyStoreProducesEmptyTrace() {
        let store = TraceStore()
        let trace = store.snapshot()
        XCTAssertTrue(trace.samples.isEmpty)
    }

    func test_recordedSamplesAppearInSnapshot() {
        let store = TraceStore()
        for i in 0..<10 { store.record(makeSample(ts: Double(i))) }
        let trace = store.snapshot()
        XCTAssertEqual(trace.samples.count, 10)
    }

    func test_snapshotTimestampsPreserveOrder() {
        let store = TraceStore()
        for i in 0..<5 { store.record(makeSample(ts: Double(i) * 0.1)) }
        let trace = store.snapshot()
        let ts = trace.samples.map(\.timestamp)
        XCTAssertEqual(ts, ts.sorted())
    }

    func test_resetClearsSamples() {
        let store = TraceStore()
        for i in 0..<5 { store.record(makeSample(ts: Double(i))) }
        store.reset()
        XCTAssertTrue(store.snapshot().samples.isEmpty)
    }

    func test_traceStatistics() {
        let store = TraceStore()
        store.record(MetricSample(timestamp: 0, cpuUsage: 0.2, memoryBytes: 100, fps: 60, thermalState: .nominal))
        store.record(MetricSample(timestamp: 1, cpuUsage: 0.8, memoryBytes: 200, fps: 30, thermalState: .nominal))
        let trace = store.snapshot()
        XCTAssertEqual(trace.averageCPU, 0.5, accuracy: 0.001)
        XCTAssertEqual(trace.peakCPU,    0.8, accuracy: 0.001)
        XCTAssertEqual(trace.peakMemoryBytes, 200)
        XCTAssertEqual(trace.averageFPS, 45, accuracy: 0.001)
    }

    func test_concurrentRecordIsSafe() {
        let store = TraceStore()
        let group = DispatchGroup()
        let queues = (0..<4).map { i in
            DispatchQueue(label: "test-\(i)", qos: .userInitiated)
        }
        for q in queues {
            group.enter()
            q.async {
                for i in 0..<250 { store.record(self.makeSample(ts: Double(i))) }
                group.leave()
            }
        }
        group.wait()
        XCTAssertEqual(store.snapshot().samples.count, 1000)
    }
}
