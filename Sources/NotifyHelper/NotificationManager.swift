import AppKit
import UserNotifications
import NotifyShared

class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()
    private var pendingCallbacks: [String: (NotificationResponse) -> Void] = [:]
    private let callbackQueue = DispatchQueue(label: "notification.callbacks")

    override init() {
        super.init()
    }

    func send(_ request: NotificationRequest, completion: @escaping (NotificationResponse) -> Void) {
        let content = UNMutableNotificationContent()

        // Set content
        content.body = request.message ?? ""
        if let title = request.title {
            content.title = title
        }
        if let subtitle = request.subtitle {
            content.subtitle = subtitle
        }

        // Set sound
        if let soundName = request.sound {
            if soundName.lowercased() == "default" {
                content.sound = .default
            } else {
                content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: soundName))
            }
        }

        // Store action data in userInfo for click handling
        var userInfo: [String: Any] = [:]
        if let openURL = request.openURL { userInfo["openURL"] = openURL }
        if let execute = request.execute { userInfo["execute"] = execute }
        if let activate = request.activate { userInfo["activate"] = activate }
        userInfo["wait"] = request.wait
        content.userInfo = userInfo

        // Add content image as attachment
        if let imagePath = request.contentImage {
            do {
                let imageURL = URL(fileURLWithPath: imagePath)
                let attachment = try UNNotificationAttachment(
                    identifier: "contentImage",
                    url: imageURL,
                    options: nil
                )
                content.attachments = [attachment]
            } catch {
                NSLog("Failed to attach image: \(error.localizedDescription)")
            }
        }

        // Set interruption level (macOS 15+ - no availability check needed)
        if let levelString = request.interruptionLevel {
            switch levelString.lowercased() {
            case "passive":
                content.interruptionLevel = .passive
            case "active":
                content.interruptionLevel = .active
            case "timesensitive":
                content.interruptionLevel = .timeSensitive
            case "critical":
                content.interruptionLevel = .critical
            default:
                content.interruptionLevel = .active
            }
        }

        // Set relevance score for notification summaries (0.0 to 1.0)
        if let score = request.relevanceScore {
            content.relevanceScore = max(0.0, min(1.0, score))
        }

        // Create request with group ID as identifier for replacement
        let identifier = request.group ?? UUID().uuidString

        let notificationRequest = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // Immediate delivery
        )

        // If waiting for interaction, store callback
        if request.wait {
            callbackQueue.sync {
                pendingCallbacks[identifier] = completion
            }
        }

        center.add(notificationRequest) { error in
            if let error = error {
                let nsError = error as NSError
                var errorMessage = error.localizedDescription

                // Provide helpful message for permission denied (UNErrorDomain code 1)
                if nsError.domain == "UNErrorDomain" && nsError.code == 1 {
                    errorMessage = "Notifications not allowed. Please enable in System Settings > Notifications > Terminal Notify Helper"
                }

                completion(NotificationResponse(
                    success: false,
                    exitCode: nsError.code == 1 ? ExitCodes.notAuthorized : ExitCodes.runtimeError,
                    error: errorMessage
                ))
            } else if !request.wait {
                // Return immediately if not waiting
                completion(NotificationResponse(success: true, exitCode: ExitCodes.success))
            }
            // If waiting, completion will be called when notification is interacted with
        }
    }

    func remove(groupID: String, completion: @escaping (NotificationResponse) -> Void) {
        if groupID.uppercased() == "ALL" {
            center.removeAllDeliveredNotifications()
            center.removeAllPendingNotificationRequests()
        } else {
            center.removeDeliveredNotifications(withIdentifiers: [groupID])
            center.removePendingNotificationRequests(withIdentifiers: [groupID])
        }
        completion(NotificationResponse(success: true, exitCode: ExitCodes.success))
    }

    func list(groupID: String?, completion: @escaping (NotificationResponse) -> Void) {
        center.getDeliveredNotifications { notifications in
            let filtered: [UNNotification]
            if let id = groupID, id.uppercased() != "ALL" {
                filtered = notifications.filter { $0.request.identifier == id }
            } else {
                filtered = notifications
            }

            let infos = filtered.map { notification -> NotificationResponse.NotificationInfo in
                let content = notification.request.content
                return NotificationResponse.NotificationInfo(
                    identifier: notification.request.identifier,
                    title: content.title,
                    subtitle: content.subtitle,
                    body: content.body
                )
            }

            completion(NotificationResponse(
                success: true,
                exitCode: ExitCodes.success,
                notifications: infos
            ))
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.notification.request.identifier
        let userInfo = response.notification.request.content.userInfo

        // Determine click result
        let clickResult: NotificationResponse.ClickResult
        switch response.actionIdentifier {
        case UNNotificationDefaultActionIdentifier:
            clickResult = .clicked
        case UNNotificationDismissActionIdentifier:
            clickResult = .closed
        default:
            clickResult = .actionButton
        }

        // Execute actions
        if clickResult == .clicked {
            if let urlString = userInfo["openURL"] as? String {
                ActionHandler.openURL(urlString)
            }
            if let command = userInfo["execute"] as? String {
                ActionHandler.executeCommand(command)
            }
            if let bundleID = userInfo["activate"] as? String {
                ActionHandler.activateApp(bundleID: bundleID)
            }
        }

        // Call pending callback if waiting
        callbackQueue.sync {
            if let callback = pendingCallbacks.removeValue(forKey: identifier) {
                callback(NotificationResponse(
                    success: true,
                    exitCode: ExitCodes.success,
                    clickAction: clickResult
                ))
            }
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notifications even when app is in foreground (macOS 15+)
        completionHandler([.banner, .sound])
    }
}
