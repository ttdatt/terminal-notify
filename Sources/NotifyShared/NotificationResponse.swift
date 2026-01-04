import Foundation

public struct NotificationResponse: Codable {
    public let success: Bool
    public let exitCode: Int32
    public let error: String?
    public let clickAction: ClickResult?
    public let notifications: [NotificationInfo]?

    public enum ClickResult: String, Codable {
        case clicked
        case closed
        case timeout
        case actionButton
    }

    public struct NotificationInfo: Codable {
        public let identifier: String
        public let title: String
        public let subtitle: String
        public let body: String

        public init(identifier: String, title: String, subtitle: String, body: String) {
            self.identifier = identifier
            self.title = title
            self.subtitle = subtitle
            self.body = body
        }
    }

    public init(
        success: Bool,
        exitCode: Int32,
        error: String? = nil,
        clickAction: ClickResult? = nil,
        notifications: [NotificationInfo]? = nil
    ) {
        self.success = success
        self.exitCode = exitCode
        self.error = error
        self.clickAction = clickAction
        self.notifications = notifications
    }
}
