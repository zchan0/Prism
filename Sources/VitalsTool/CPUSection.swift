import Foundation

/// Cumulative CPU time across all cores, in scheduler ticks, from `host_statistics`.
///
/// One sample says nothing about load: it counts from boot. Load is the difference between two samples.
public struct CPUTicks: Equatable, Sendable {
    public var user: UInt32
    public var system: UInt32
    public var idle: UInt32
    public var nice: UInt32

    public init(user: UInt32, system: UInt32, idle: UInt32, nice: UInt32) {
        self.user = user
        self.system = system
        self.idle = idle
        self.nice = nice
    }

    public static func read() -> CPUTicks? {
        var info = host_cpu_load_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<host_cpu_load_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics(Host.port, HOST_CPU_LOAD_INFO, $0, &count)
            }
        }
        guard status == KERN_SUCCESS else { return nil }
        // Indexed by CPU_STATE_USER, CPU_STATE_SYSTEM, CPU_STATE_IDLE and CPU_STATE_NICE.
        return CPUTicks(user: info.cpu_ticks.0, system: info.cpu_ticks.1, idle: info.cpu_ticks.2, nice: info.cpu_ticks.3)
    }
}

/// How busy the CPU was between two samples, as a share of every core.
public struct CPUReading: Equatable, Sendable {
    /// Includes `nice` time: to the person it is still their apps using the CPU.
    public var user: Double
    public var system: Double

    public init(user: Double, system: Double) {
        self.user = user
        self.system = system
    }

    public var usage: Double { min(1, max(0, user + system)) }

    /// Nil when no time passed between the two samples.
    public static func between(_ old: CPUTicks, _ new: CPUTicks) -> CPUReading? {
        // The counters are 32 bits and wrap, so the difference is taken with wrapping arithmetic.
        let user = UInt64(new.user &- old.user) + UInt64(new.nice &- old.nice)
        let system = UInt64(new.system &- old.system)
        let idle = UInt64(new.idle &- old.idle)
        let total = user + system + idle
        guard total > 0 else { return nil }
        return CPUReading(user: Double(user) / Double(total), system: Double(system) / Double(total))
    }

    public var reading: Reading {
        Reading(
            kind: .cpu,
            value: VitalsStrings.percent(Self.percent(usage)),
            detail: VitalsStrings.cpuSplit(user: Self.percent(user), system: Self.percent(system)),
            fraction: usage
        )
    }

    private static func percent(_ fraction: Double) -> Int {
        Int((fraction * 100).rounded())
    }
}

/// The host port, taken once: every `mach_host_self()` call adds a reference to it.
enum Host {
    static let port = mach_host_self()
}
