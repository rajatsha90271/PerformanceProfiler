//
//  CPUSampler.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 05/06/2026.
//

import Darwin

/// Samples total CPU usage across all threads of the current process via the
/// Mach `thread_basic_info` API. Returns a value in [0, processorCount] — e.g.
/// 1.5 means 150% of one core.
public final class CPUSampler {
    public init() {}

    public func sample() -> Float {
        var threadList: thread_act_array_t?
        var threadCount = mach_msg_type_number_t(0)

        guard task_threads(mach_task_self_, &threadList, &threadCount) == KERN_SUCCESS,
              let threads = threadList else { return 0 }

        defer {
            // Mach gives us ownership of the thread port array; we must free it.
            vm_deallocate(
                mach_task_self_,
                vm_address_t(bitPattern: threads),
                vm_size_t(Int(threadCount) * MemoryLayout<thread_t>.stride)
            )
        }

        var total: Float = 0

        // THREAD_BASIC_INFO_COUNT is a C macro not bridged to Swift; compute it manually.
        let threadBasicInfoCount = mach_msg_type_number_t(
            MemoryLayout<thread_basic_info>.size / MemoryLayout<natural_t>.size
        )
        // TH_FLAGS_IDLE (0x2) and TH_USAGE_SCALE (1000) are also unbridged macros.
        let thFlagsIdle   = Int32(0x2)
        let thUsageScale  = Float(1000)

        for i in 0..<Int(threadCount) {
            var info  = thread_basic_info()
            var count = threadBasicInfoCount

            let kr = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                    thread_info(threads[i], thread_flavor_t(THREAD_BASIC_INFO), $0, &count)
                }
            }

            // Skip idle threads; they report cpu_usage but aren't doing real work.
            guard kr == KERN_SUCCESS, info.flags & thFlagsIdle == 0 else { continue }
            total += Float(info.cpu_usage) / thUsageScale
        }

        return total
    }
}
