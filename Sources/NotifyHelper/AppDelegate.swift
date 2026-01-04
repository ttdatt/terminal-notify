import AppKit
import UserNotifications
import NotifyShared

class AppDelegate: NSObject, NSApplicationDelegate {
    private var notificationManager: NotificationManager!
    private var ipcServer: IPCServer!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("terminal-notify-helper starting...")

        // Initialize notification manager FIRST (before using it)
        notificationManager = NotificationManager()

        // Set up notification center
        let center = UNUserNotificationCenter.current()
        center.delegate = notificationManager

        // Request notification authorization
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                NSLog("Notification authorization error: \(error.localizedDescription)")
            }
            if granted {
                NSLog("Notification authorization GRANTED")
            } else {
                NSLog("Notification authorization DENIED - Please enable in System Settings > Notifications > Terminal Notify Helper")
            }
        }

        // Check current authorization status
        center.getNotificationSettings { settings in
            NSLog("Notification settings - Authorization: \(settings.authorizationStatus.rawValue), Alert: \(settings.alertSetting.rawValue)")
            switch settings.authorizationStatus {
            case .notDetermined:
                NSLog("Notification permission: Not yet requested")
            case .denied:
                NSLog("Notification permission: DENIED - Enable in System Settings > Notifications")
            case .authorized:
                NSLog("Notification permission: Authorized")
            case .provisional:
                NSLog("Notification permission: Provisional")
            @unknown default:
                NSLog("Notification permission: Unknown status")
            }
        }

        // Start IPC server
        ipcServer = IPCServer(notificationManager: notificationManager)
        ipcServer.start()

        NSLog("terminal-notify-helper started and ready")
    }

    func applicationWillTerminate(_ notification: Notification) {
        ipcServer?.stop()
        NSLog("terminal-notify-helper stopped")
    }
}
