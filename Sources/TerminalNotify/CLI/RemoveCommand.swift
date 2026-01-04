import ArgumentParser
import Foundation
import NotifyShared

struct RemoveCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove delivered notifications"
    )

    @Argument(help: "Group ID to remove (use 'ALL' to remove all notifications)")
    var groupID: String

    mutating func run() throws {
        let request = NotificationRequest(
            action: .remove,
            group: groupID
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
}
