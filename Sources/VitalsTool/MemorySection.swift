import Foundation

/// Memory as macOS reports it, read through `host_statistics64`.
///
/// "Used" here is the App Memory + Wired + Compressed idea of used rather than "total minus free": macOS keeps most
/// free RAM in the file cache, so `total - free` would read as 90% used on a perfectly healthy machine.
public struct MemoryReading: Equatable, Sendable {
    public var total: Int64
    public var used: Int64

    public init(total: Int64, used: Int64) {
        self.total = total
        self.used = used
    }

    public var fraction: Double {
        guard total > 0 else { return 0 }
        return min(1, max(0, Double(used) / Double(total)))
    }

    public var reading: Reading {
        Reading(
            kind: .memory,
            value: ByteText.compact(used),
            detail: VitalsStrings.ofTotal(ByteText.compact(total)),
            fraction: fraction,
            isTight: fraction > 0.9
        )
    }

    public static func read() -> MemoryReading? {
        var stats = vm_statistics64_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &stats) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(Host.port, HOST_VM_INFO64, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        var pageSize: vm_size_t = 0
        guard host_page_size(Host.port, &pageSize) == KERN_SUCCESS else { return nil }
        let page = Int64(pageSize)
        let total = Int64(ProcessInfo.processInfo.physicalMemory)
        // App memory plus wired plus compressed is what the system would have to swap out to free.
        let used = (Int64(stats.active_count) + Int64(stats.wire_count) + Int64(stats.compressor_page_count)) * page
        return MemoryReading(total: total, used: min(used, total))
    }
}
