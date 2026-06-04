//
//  FPSSampler.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 05/06/2026.
//

import QuartzCore
import UIKit
import Atomics

/// Measures rendered frames per second using `CADisplayLink`.
///
/// Must be started and stopped on the main thread. `currentFPS` is safe to read
/// from any thread (backed by an atomic).
public final class FPSSampler {
    private var displayLink: CADisplayLink?

    // Atomic storage so the sampler queue can read without a lock.
    private let _fps = ManagedAtomic<UInt32>(0)   // stored as fixed-point *10 → 0.1 fps resolution
    private let _frameCount = ManagedAtomic<Int>(0)
    private var lastTimestamp: Double = 0

    public init() {}

    // MARK: - Control (main thread)

    @MainActor
    public func start() {
        guard displayLink == nil else { return }
        let link = CADisplayLink(target: self, selector: #selector(tick(_:)))
        link.add(to: .main, forMode: .common)
        displayLink = link
    }

    @MainActor
    public func stop() {
        displayLink?.invalidate()
        displayLink = nil
        lastTimestamp = 0
        _frameCount.store(0, ordering: .relaxed)
        _fps.store(0, ordering: .relaxed)
    }

    // MARK: - Reading (any thread)

    public var currentFPS: Float {
        Float(_fps.load(ordering: .relaxed)) / 10.0
    }

    // MARK: - Private

    @objc private func tick(_ link: CADisplayLink) {
        let now = link.timestamp

        if lastTimestamp == 0 {
            lastTimestamp = now
            return
        }

        let count = _frameCount.loadThenWrappingIncrement(ordering: .relaxed) + 1
        let elapsed = now - lastTimestamp

        // Recompute FPS every 0.5 s for a responsive but stable reading.
        if elapsed >= 0.5 {
            let fps = Double(count) / elapsed
            _fps.store(UInt32(fps * 10), ordering: .releasing)
            _frameCount.store(0, ordering: .relaxed)
            lastTimestamp = now
        }
    }
}
