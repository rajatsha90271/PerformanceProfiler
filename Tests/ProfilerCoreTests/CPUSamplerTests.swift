//
//  CPUSamplerTests.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 19/06/2026.
//

import XCTest
@testable import ProfilerCore

final class CPUSamplerTests: XCTestCase {

    func test_sampleReturnsNonNegativeValue() {
        let sampler = CPUSampler()
        let cpu = sampler.sample()
        XCTAssertGreaterThanOrEqual(cpu, 0)
    }

    func test_sampleIsReasonablyCapped() {
        let sampler = CPUSampler()
        let processorCount = Float(ProcessInfo.processInfo.processorCount)
        let cpu = sampler.sample()
        // Allow a small margin above processorCount for timing jitter
        XCTAssertLessThanOrEqual(cpu, processorCount + 0.1,
            "CPU usage cannot exceed total core count")
    }

    func test_sampleUnderLoadIsPositive() {
        let sampler = CPUSampler()

        // Generate CPU load on a background thread
        let expectation = expectation(description: "load generated")
        let workItem = DispatchWorkItem {
            var x = 0.0
            for i in 0..<1_000_000 { x += Double(i).squareRoot() }
            _ = x
            expectation.fulfill()
        }
        DispatchQueue.global(qos: .userInitiated).async(execute: workItem)

        // Sample during the load
        wait(for: [expectation], timeout: 5)
        let cpu = sampler.sample()
        XCTAssertGreaterThan(cpu, 0, "Should detect CPU activity")
    }
}
