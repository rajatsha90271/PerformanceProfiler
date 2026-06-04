//
//  MemorySampler.swift
//  PerformanceProfiler
//
//  Created by Rajat Sharma on 05/06/2026.
//

import Darwin

/// Samples the process's physical memory footprint via `task_vm_info`.
/// `phys_footprint` matches what Xcode's memory gauge and Instruments report —
/// it accounts for compressed memory and shared pages correctly.
public final class MemorySampler {
    public init() {}

    public func sample() -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(
            MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size
        )

        let kr = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }

        return kr == KERN_SUCCESS ? info.phys_footprint : 0
    }
}
