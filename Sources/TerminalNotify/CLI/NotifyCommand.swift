import ArgumentParser

struct NotifyCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "terminal-notify",
        abstract: "Send macOS notifications from the command line",
        version: "1.0.0",
        subcommands: [SendCommand.self, RemoveCommand.self, ListCommand.self],
        defaultSubcommand: SendCommand.self
    )
}
