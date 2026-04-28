import Foundation
import os.log

extension OSLog {
    private static var subsystem = Bundle.main.bundleIdentifier ?? "com.mlc.chat"

    static let ui = OSLog(subsystem: subsystem, category: "UI")
    static let engine = OSLog(subsystem: subsystem, category: "Engine")
    static let database = OSLog(subsystem: subsystem, category: "Database")
    static let app = OSLog(subsystem: subsystem, category: "App")
}

func debugLog(_ message: String, category: OSLog = .app) {
    os_log("DEBUG: %{public}@", log: category, type: .debug, message)
    NSLog("DEBUG: %@", message)
    print("DEBUG: \(message)")
}
