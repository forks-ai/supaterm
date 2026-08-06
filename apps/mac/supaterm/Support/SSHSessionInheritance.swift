import Darwin
import Foundation
import SupatermCLIShared

public enum SSHSessionInheritance {
  public typealias ArgumentsProvider = @Sendable (pid_t) -> [String]?

  private static let multiplexerProcessName = SupatermBundleLayout.zmxExecutableName

  public static func startupCommand(
    zmxSessionName: String,
    cliPath: String?,
    table: ProcessTable = .snapshot(),
    arguments: ArgumentsProvider = { ProcessTable.arguments(forProcessID: $0) }
  ) -> String? {
    guard
      let shell = sessionShell(zmxSessionName: zmxSessionName, table: table, arguments: arguments)
    else {
      return nil
    }

    for candidate in table.foregroundGroup(onTerminalOf: shell) {
      guard
        let argumentList = arguments(candidate.processID),
        let command = SupatermSSHCommand.commandLine(
          forArguments: argumentList,
          cliPath: cliPath
        )
      else {
        continue
      }
      return SupatermShellCommand.interactiveStartupCommand(for: command)
    }

    return nil
  }

  private static func sessionShell(
    zmxSessionName: String,
    table: ProcessTable,
    arguments: ArgumentsProvider
  ) -> ProcessEntry? {
    for entry in table.entries where entry.name == multiplexerProcessName {
      guard arguments(entry.processID)?.contains(zmxSessionName) == true else { continue }
      if let shell = table.children(of: entry.processID)
        .first(where: { $0.name != multiplexerProcessName })
      {
        return shell
      }
    }
    return nil
  }
}
