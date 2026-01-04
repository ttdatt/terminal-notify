import ArgumentParser
import Foundation
import NotifyShared

struct SendCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "send",
        abstract: "Send a notification"
    )

    // Core options
    @Option(name: .customLong("message"), help: "Notification message body")
    var message: String?

    @Option(name: .customLong("title"), help: "Notification title")
    var title: String?

    @Option(name: .customLong("subtitle"), help: "Subtitle text")
    var subtitle: String?

    @Option(name: .customLong("sound"), help: "Sound name (e.g., 'default', 'Basso', 'Glass')")
    var sound: String?

    // Interaction options
    @Option(name: .customLong("open"), help: "URL to open when notification is clicked")
    var openURL: String?

    @Option(name: .customLong("execute"), help: "Shell command to execute when clicked")
    var execute: String?

    @Option(name: .customLong("activate"), help: "Bundle ID of app to activate when clicked")
    var activate: String?

    // Customization
    @Option(name: .customLong("appIcon"), help: "Path to custom app icon")
    var appIcon: String?

    @Option(name: .customLong("contentImage"), help: "Path to content image attachment")
    var contentImage: String?

    // Management
    @Option(name: .customLong("group"), help: "Group ID for notification replacement")
    var group: String?

    // Advanced
    @Option(name: .customLong("sender"), help: "Fake sender bundle ID")
    var sender: String?

    @Option(name: .customLong("interruptionLevel"), help: "Notification priority: passive, active, timeSensitive, critical")
    var interruptionLevel: String?

    @Option(name: .customLong("relevanceScore"), help: "Priority in notification summaries (0.0-1.0)")
    var relevanceScore: Double?

    @Flag(name: .customLong("wait"), help: "Wait for user interaction before returning")
    var wait = false

    mutating func run() throws {
        // Read from stdin if message not provided
        let finalMessage = message ?? readFromStdin()
        guard let msg = finalMessage, !msg.isEmpty else {
            throw ValidationError("Message is required (via --message or stdin)")
        }

        let request = NotificationRequest(
            action: .send,
            message: msg,
            title: title,
            subtitle: subtitle,
            sound: sound,
            openURL: openURL,
            execute: execute,
            activate: activate,
            appIcon: appIcon,
            contentImage: contentImage,
            group: group,
            sender: sender,
            interruptionLevel: interruptionLevel,
            relevanceScore: relevanceScore,
            wait: wait
        )

        do {
            let client = HelperClient()
            let response = try client.send(request)

            if !response.success {
                if let error = response.error {
                    FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
                }
                throw ExitCode(rawValue: response.exitCode)
            }

            if let clickAction = response.clickAction {
                print(clickAction.rawValue)
            }
        } catch let error as HelperClient.ClientError {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            let code: Int32
            switch error {
            case .helperNotRunning:
                code = ExitCodes.helperNotRunning
            case .connectionFailed, .communicationError:
                code = ExitCodes.runtimeError
            }
            throw ExitCode(rawValue: code)
        }
    }

    private func readFromStdin() -> String? {
        // isatty returns non-zero if fd is a terminal, 0 if not
        guard isatty(STDIN_FILENO) == 0 else { return nil }
        let data = FileHandle.standardInput.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
