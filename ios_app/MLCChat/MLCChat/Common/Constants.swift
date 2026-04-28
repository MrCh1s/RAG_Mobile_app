import Foundation
import os.log

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
