import Darwin
import Foundation
import Testing

@testable import SupatermSupport

struct SSHSessionInheritanceTests {
  private static let sessionName = "spt-37a8eec1ce19687d-8d9a2ce8-6212-4234-b419-df4c52a451ef"
  private static let cliPath = "/Applications/supaterm.app/Contents/MacOS/sp"
  private static let paneTerminal: dev_t = 268_435_457
  private static let sessionTerminal: dev_t = 268_435_465

  private static func table(shellForegroundGroup: pid_t, extra: [ProcessEntry] = []) -> ProcessTable {
    ProcessTable(
      entries: [
        ProcessEntry(
          processID: 100,
          parentProcessID: 1,
          processGroupID: 100,
          foregroundProcessGroupID: 100,
          terminalDevice: paneTerminal,
          name: "zmx"
        ),
        ProcessEntry(
          processID: 101,
          parentProcessID: 100,
          processGroupID: 101,
          foregroundProcessGroupID: -1,
          terminalDevice: -1,
          name: "zmx"
        ),
        ProcessEntry(
          processID: 200,
          parentProcessID: 101,
          processGroupID: 200,
          foregroundProcessGroupID: shellForegroundGroup,
          terminalDevice: sessionTerminal,
          name: "login"
        ),
      ] + extra
    )
  }

  private static func arguments(_ table: [pid_t: [String]]) -> SSHSessionInheritance.ArgumentsProvider {
    { table[$0] }
  }

  @Test
  func inheritsForegroundSSHCommandFromSessionShell() throws {
    let resolved = SSHSessionInheritance.startupCommand(
      zmxSessionName: Self.sessionName,
      cliPath: Self.cliPath,
      table: Self.table(
        shellForegroundGroup: 300,
        extra: [
          ProcessEntry(
            processID: 300,
            parentProcessID: 201,
            processGroupID: 300,
            foregroundProcessGroupID: 300,
            terminalDevice: Self.sessionTerminal,
            name: "ssh"
          )
        ]
      ),
      arguments: Self.arguments([
        100: ["zmx", "attach", Self.sessionName, "/usr/bin/login"],
        101: ["zmx", "attach", Self.sessionName, "/usr/bin/login"],
        200: ["/usr/bin/login", "-flp", "khoi"],
        300: [
          "/usr/bin/ssh",
          "-o", "SendEnv=COLORTERM",
          "-o", "SendEnv=TERM_PROGRAM",
          "-o", "SendEnv=TERM_PROGRAM_VERSION",
          "-p", "2222",
          "dev@example.com",
        ],
      ])
    )

    let command = try #require(resolved)
    #expect(command.hasPrefix("\(Self.cliPath) ssh -- -p 2222 dev@example.com;"))
    #expect(!command.contains("SendEnv"))
  }

  @Test
  func ignoresBackgroundSSHOutsideTheForegroundGroup() {
    let command = SSHSessionInheritance.startupCommand(
      zmxSessionName: Self.sessionName,
      cliPath: Self.cliPath,
      table: Self.table(
        shellForegroundGroup: 200,
        extra: [
          ProcessEntry(
            processID: 300,
            parentProcessID: 201,
            processGroupID: 300,
            foregroundProcessGroupID: 200,
            terminalDevice: Self.sessionTerminal,
            name: "ssh"
          )
        ]
      ),
      arguments: Self.arguments([
        100: ["zmx", "attach", Self.sessionName],
        101: ["zmx", "attach", Self.sessionName],
        200: ["/usr/bin/login", "-flp", "khoi"],
        300: ["/usr/bin/ssh", "dev@example.com"],
      ])
    )

    #expect(command == nil)
  }

  @Test
  func ignoresSessionsBelongingToAnotherSurface() {
    let command = SSHSessionInheritance.startupCommand(
      zmxSessionName: "spt-37a8eec1ce19687d-00000000-0000-0000-0000-000000000000",
      cliPath: Self.cliPath,
      table: Self.table(shellForegroundGroup: 200),
      arguments: Self.arguments([
        100: ["zmx", "attach", Self.sessionName],
        101: ["zmx", "attach", Self.sessionName],
        200: ["/usr/bin/login", "-flp", "khoi"],
      ])
    )

    #expect(command == nil)
  }

  @Test
  func returnsNilWhenTheForegroundCommandIsAShell() {
    let command = SSHSessionInheritance.startupCommand(
      zmxSessionName: Self.sessionName,
      cliPath: Self.cliPath,
      table: Self.table(shellForegroundGroup: 200),
      arguments: Self.arguments([
        100: ["zmx", "attach", Self.sessionName],
        101: ["zmx", "attach", Self.sessionName],
        200: ["/usr/bin/login", "-flp", "khoi"],
      ])
    )

    #expect(command == nil)
  }

  @Test
  func fallsBackToALoginShellAfterTheRemoteSessionEnds() throws {
    let command = try #require(
      SSHSessionInheritance.startupCommand(
        zmxSessionName: Self.sessionName,
        cliPath: Self.cliPath,
        table: Self.table(
          shellForegroundGroup: 300,
          extra: [
            ProcessEntry(
              processID: 300,
              parentProcessID: 201,
              processGroupID: 300,
              foregroundProcessGroupID: 300,
              terminalDevice: Self.sessionTerminal,
              name: "ssh"
            )
          ]
        ),
        arguments: Self.arguments([
          100: ["zmx", "attach", Self.sessionName],
          101: ["zmx", "attach", Self.sessionName],
          200: ["/usr/bin/login", "-flp", "khoi"],
          300: ["ssh", "example.com"],
        ])
      )
    )

    #expect(command.hasPrefix("\(Self.cliPath) ssh -- example.com;"))
    #expect(command.contains("exec"))
  }
}
