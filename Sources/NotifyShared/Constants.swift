import Foundation

public enum Constants {
    public static let helperBundleIdentifier = "com.terminal-notify.helper"
    public static let socketName = "terminal-notify.sock"

    public static var socketPath: String {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("terminal-notify")
        return dir.appendingPathComponent(socketName).path
    }

    public static var socketDirectory: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("terminal-notify")
    }
}

public enum ExitCodes {
    public static let success: Int32 = 0
    public static let runtimeError: Int32 = 1
    public static let usageError: Int32 = 2
    public static let notAuthorized: Int32 = 70
    public static let actionFailed: Int32 = 71
    public static let helperNotRunning: Int32 = 72
}
