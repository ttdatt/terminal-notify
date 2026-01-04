import ArgumentParser
import Foundation
import NotifyShared

struct ListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List delivered notifications"
    )

    @Argument(help: "Group ID to list (use 'ALL' for all notifications)")
    var groupID: String = "ALL"

    mutating func run() throws {
        let request = NotificationRequest(
            action: .list,
            group: groupID
        )

        do {
            let client = HelperClient()
            let response = try client.send(request)

            if !response.success {
                if let error = response.error {
                    FileHandle.standardError.write(Data("Error: \(error)\n".utf8))
                }
                throw ExitCode(rawValue: response.exitCode) ?? ExitCode.failure
            }

            // Print notifications in tab-separated format
            if let notifications = response.notifications {
                for info in notifications {
                    print("\(info.identifier)\t\(info.title)\t\(info.subtitle)\t\(info.body)")
                }
            }
        } catch let error as HelperClient.ClientError {
            FileHandle.standardError.write(Data("Error: \(error.localizedDescription)\n".utf8))
            throw ExitCode(rawValue: ExitCodes.helperNotRunning) ?? ExitCode.failure
        }
    }
}
