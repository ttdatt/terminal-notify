import AppKit

struct ActionHandler {
    static func openURL(_ urlString: String) {
        guard let url = URL(string: urlString) else {
            NSLog("Invalid URL: \(urlString)")
            return
        }
        NSWorkspace.shared.open(url)
    }

    static func executeCommand(_ command: String) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/bin/sh")
            process.arguments = ["-c", command]

            do {
                try process.run()
                process.waitUntilExit()
            } catch {
                NSLog("Failed to execute command: \(error.localizedDescription)")
            }
        }
    }

    static func activateApp(bundleID: String) {
        if let app = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            app.activate()
        } else {
            // Launch the app if not running (macOS 15+ - no availability check needed)
            let config = NSWorkspace.OpenConfiguration()
            config.activates = true

            if let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
                    if let error = error {
                        NSLog("Failed to launch app \(bundleID): \(error.localizedDescription)")
                    }
                }
            } else {
                NSLog("App not found with bundle ID: \(bundleID)")
            }
        }
    }
}
