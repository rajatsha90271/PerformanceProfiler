//
//  RingBuffer.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 02/03/2026.
//

import Atomics

/// Lock-free single-producer / single-consumer ring buffer.
///
/// Correctness relies on two invariants:
///   - Only one thread calls `push` at a time  (the producer).
///   - Only one thread calls `pop`  at a time  (the consumer).
///
/// The atomic head/tail indices provide the acquire–release happens-before edge
/// that makes the non-atomic storage reads/writes safe:
///   push: write storage[h]  →  releasing-store(head)
///   pop:  acquiring-load(head)  →  read storage[t]
///
/// Capacity must be a power of two. One slot is reserved to distinguish
/// full from empty, so usable capacity is `capacity - 1`.
public final class SPSCRingBuffer<Element> {
    private let mask: Int
    private var storage: ContiguousArray<Element?>

    // Written only by producer; read by both.
    private let _head = ManagedAtomic<Int>(0)
    // Written only by consumer; read by both.
    private let _tail = ManagedAtomic<Int>(0)

    public init(capacity: Int) {
        precondition(capacity.isPowerOfTwo && capacity > 1,
                     "Capacity must be a power of two greater than 1")
        mask = capacity &- 1
        storage = ContiguousArray(repeating: nil, count: capacity)
    }

    // MARK: - Producer API

    /// Appends `element`. Returns `false` and drops the element when full.
    @discardableResult
    public func push(_ element: Element) -> Bool {
        let h    = _head.load(ordering: .relaxed)
        let next = (h &+ 1) & mask
        // Acquiring load: ensures we see the consumer's latest tail store.
        guard next != _tail.load(ordering: .acquiring) else { return false }
        storage[h] = element
        // Releasing store: makes the storage write visible to the consumer.
        _head.store(next, ordering: .releasing)
        return true
    }

    // MARK: - Consumer API

    /// Removes and returns the oldest element, or `nil` when empty.
    public func pop() -> Element? {
        let t = _tail.load(ordering: .relaxed)
        // Acquiring load: ensures we see the producer's storage write.
        guard t != _head.load(ordering: .acquiring) else { return nil }
        let element = storage[t]
        storage[t] = nil                              // allow ARC to release
        _tail.store((t &+ 1) & mask, ordering: .releasing)
        return element
    }

    // MARK: - Inspection (approximate; both sides may race)

    public var isEmpty: Bool {
        _head.load(ordering: .relaxed) == _tail.load(ordering: .relaxed)
    }

    /// Drains all current elements into an array. Called from the consumer thread.
    public func drain() -> [Element] {
        var result: [Element] = []
        while let e = pop() { result.append(e) }
        return result
    }
}

// MARK: - Helpers

extension Int {
    var isPowerOfTwo: Bool { self > 0 && (self & (self &- 1)) == 0 }

    var nextPowerOfTwo: Int {
        guard self > 1 else { return 2 }
        return 1 << (Int.bitWidth - (self &- 1).leadingZeroBitCount)
    }
}
