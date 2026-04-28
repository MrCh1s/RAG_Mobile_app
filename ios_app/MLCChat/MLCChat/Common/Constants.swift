import Foundation
import os.log
import Darwin

struct Constants {
    static let prebuiltModelDir = "bundle"
    static let appConfigFileName = "bundle/mlc-app-config.json"
    static let modelConfigFileName = "mlc-chat-config.json"
    static let paramsConfigFileName = "tensor-cache.json"
}

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "mlc.Chat"

    static let ui = OSLog(subsystem: subsystem, category: "UI")
    static let engine = OSLog(subsystem: subsystem, category: "Engine")
    static let database = OSLog(subsystem: subsystem, category: "Database")
    static let app = OSLog(subsystem: subsystem, category: "App")
}

func debugLog(_ message: String, category: OSLog = .app) {
    os_log("DEBUG: %{public}@", log: category, message)
    NSLog("DEBUG: %@", message)
    print("DEBUG: \(message)")
}

struct MemoryUtil {
    static func getMemoryUsage() -> UInt64 {
        var taskInfo = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &taskInfo) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        if kerr == KERN_SUCCESS {
            return taskInfo.resident_size
        } else {
            return 0
        }
    }

    static func getMemoryUsageString() -> String {
        let usage = getMemoryUsage()
        let usageInMB = Double(usage) / (1024 * 1024)
        if usageInMB > 1024 {
            return String(format: "%.2f GB", usageInMB / 1024)
        } else {
            return String(format: "%.0f MB", usageInMB)
        }
    }
}
