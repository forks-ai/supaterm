import Darwin
import Foundation
import SupatermCLIShared

public enum SSHSessionInheritance {
  typealias InvocationProvider = @Sendable (pid_t) -> ProcessInvocation?

  private static let multiplexerProcessName = SupatermBundleLayout.zmxExecutableName

  public static func startupCommand(
    zmxSessionName: String,
    cliPath: String?
  ) -> String? {
    startupCommand(
      zmxSessionName: zmxSessionName,
      cliPath: cliPath,
      table: .snapshot(),
      invocation: { ProcessTable.invocation(forProcessID: $0) }
    )
  }

  static func startupCommand(
    zmxSessionName: String,
    cliPath: String?,
    table: ProcessTable,
    invocation: InvocationProvider
  ) -> String? {
    guard
      let shell = sessionShell(zmxSessionName: zmxSessionName, table: table, invocation: invocation)
    else {
      return nil
    }

    for candidate in table.foregroundGroup(onTerminalOf: shell) {
      guard
        let process = invocation(candidate.processID),
        let command = SupatermSSHCommand.commandLine(
          forArguments: process.arguments,
          terminalType: process.terminalType,
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
    invocation: InvocationProvider
  ) -> ProcessEntry? {
    for entry in table.entries where entry.name == multiplexerProcessName {
      guard invocation(entry.processID)?.arguments.contains(zmxSessionName) == true else { continue }
      if let shell = table.children(of: entry.processID)
        .first(where: { $0.name != multiplexerProcessName })
      {
        return shell
      }
    }
    return nil
  }
}
