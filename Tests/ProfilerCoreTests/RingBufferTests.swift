//
//  RingBufferTests.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 19/06/2026.
//

import XCTest
import Atomics
@testable import ProfilerCore

final class RingBufferTests: XCTestCase {

    func test_emptyBufferReturnsNil() {
        let buf = SPSCRingBuffer<Int>(capacity: 4)
        XCTAssertNil(buf.pop())
        XCTAssertTrue(buf.isEmpty)
    }

    func test_pushAndPopSingleElement() {
        let buf = SPSCRingBuffer<Int>(capacity: 4)
        XCTAssertTrue(buf.push(42))
        XCTAssertFalse(buf.isEmpty)
        XCTAssertEqual(buf.pop(), 42)
        XCTAssertTrue(buf.isEmpty)
    }

    func test_FIFOOrdering() {
        let buf = SPSCRingBuffer<Int>(capacity: 8)
        for i in 0..<5 { buf.push(i) }
        for i in 0..<5 { XCTAssertEqual(buf.pop(), i) }
    }

    func test_fullBufferDropsNewElement() {
        // Capacity 4 → 3 usable slots (one sacrificed for full/empty distinction)
        let buf = SPSCRingBuffer<Int>(capacity: 4)
        XCTAssertTrue(buf.push(1))
        XCTAssertTrue(buf.push(2))
        XCTAssertTrue(buf.push(3))
        XCTAssertFalse(buf.push(4))   // full
    }

    func test_wrapAround() {
        let buf = SPSCRingBuffer<Int>(capacity: 4)
        buf.push(1); buf.push(2); buf.push(3)
        _ = buf.pop(); _ = buf.pop()   // consume 2
        buf.push(4); buf.push(5)       // fill again across boundary
        XCTAssertEqual(buf.pop(), 3)
        XCTAssertEqual(buf.pop(), 4)
        XCTAssertEqual(buf.pop(), 5)
        XCTAssertTrue(buf.isEmpty)
    }

    func test_drainReturnsAllElements() {
        let buf = SPSCRingBuffer<Int>(capacity: 8)
        for i in 0..<5 { buf.push(i) }
        let drained = buf.drain()
        XCTAssertEqual(drained, [0, 1, 2, 3, 4])
        XCTAssertTrue(buf.isEmpty)
    }

    func test_concurrentProducerConsumer() {
        let capacity = 1024
        let buf = SPSCRingBuffer<Int>(capacity: capacity)
        let itemCount = 10_000
        let expectation = expectation(description: "all items received")
        var received = [Int]()

        let producer = Thread {
            for i in 0..<itemCount {
                while !buf.push(i) { Thread.sleep(forTimeInterval: 0.000_001) }
            }
        }

        let consumer = Thread {
            while received.count < itemCount {
                if let v = buf.pop() { received.append(v) }
            }
            expectation.fulfill()
        }

        consumer.start()
        producer.start()
        wait(for: [expectation], timeout: 10)

        XCTAssertEqual(received.count, itemCount)
        // Verify FIFO ordering is preserved
        for (i, v) in received.enumerated() { XCTAssertEqual(v, i) }
    }
}
