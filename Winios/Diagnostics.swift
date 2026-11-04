import Foundation
import Metal
import Darwin

struct RuntimeDiagnostics {
    let currentMemoryMB: Double
    let peakMemoryMB: Double
    let metalDevice: String
    let jitStatus: String

    static func capture() -> RuntimeDiagnostics {
        let memory = MemorySampler.shared.sample()
        return RuntimeDiagnostics(
            currentMemoryMB: memory.current,
            peakMemoryMB: memory.peak,
            metalDevice: MTLCreateSystemDefaultDevice()?.name ?? "Unavailable",
            jitStatus: "Not integrated; no JIT capability is claimed"
        )
    }
}

private final class MemorySampler {
    static let shared = MemorySampler()
    private(set) var peak = 0.0

    func sample() -> (current: Double, peak: Double) {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        let current = result == KERN_SUCCESS ? Double(info.resident_size) / 1_048_576 : 0
        peak = max(peak, current)
        return (current, peak)
    }
}
