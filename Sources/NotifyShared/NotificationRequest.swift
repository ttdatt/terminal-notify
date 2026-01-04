import Foundation

public struct NotificationRequest: Codable {
    public let action: RequestAction
    public let message: String?
    public let title: String?
    public let subtitle: String?
    public let sound: String?
    public let openURL: String?
    public let execute: String?
    public let activate: String?
    public let appIcon: String?
    public let contentImage: String?
    public let group: String?
    public let sender: String?
    public let interruptionLevel: String?  // passive, active, timeSensitive, critical
    public let relevanceScore: Double?     // 0.0 to 1.0 for notification summary priority
    public let wait: Bool

    public enum RequestAction: String, Codable {
        case send
        case remove
        case list
    }

    public init(
        action: RequestAction = .send,
        message: String? = nil,
        title: String? = nil,
        subtitle: String? = nil,
        sound: String? = nil,
        openURL: String? = nil,
        execute: String? = nil,
        activate: String? = nil,
        appIcon: String? = nil,
        contentImage: String? = nil,
        group: String? = nil,
        sender: String? = nil,
        interruptionLevel: String? = nil,
        relevanceScore: Double? = nil,
        wait: Bool = false
    ) {
        self.action = action
        self.message = message
        self.title = title
        self.subtitle = subtitle
        self.sound = sound
        self.openURL = openURL
        self.execute = execute
        self.activate = activate
        self.appIcon = appIcon
        self.contentImage = contentImage
        self.group = group
        self.sender = sender
        self.interruptionLevel = interruptionLevel
        self.relevanceScore = relevanceScore
        self.wait = wait
    }
}
