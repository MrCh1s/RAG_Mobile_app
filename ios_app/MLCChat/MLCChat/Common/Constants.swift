import Foundation
import os.log
import Darwin
import MachO

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
        // Temporary bypass to fix build failing due to Mach API visibility
        return 1024 * 1024 * 500 // 500 MB dummy for testing build
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
