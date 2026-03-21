import Foundation

enum MemoryMonitor {
    static var residentSize: UInt64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(
            MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size
        )
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return info.resident_size
    }

    static var residentSizeMB: Double {
        Double(residentSize) / 1_048_576
    }

    /// 45MB threshold — leave 5-25MB headroom for the system
    static var isUnderPressure: Bool {
        residentSizeMB > 45
    }
}
