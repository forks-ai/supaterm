import Foundation
import Testing

@testable import SupatermCLIShared

struct SupatermShellCommandTests {
  @Test
  func escapedTokenLeavesSafeTokensUnquoted() {
    #expect(SupatermShellCommand.escapedToken("abcXYZ09@%_+=:,./-") == "abcXYZ09@%_+=:,./-")
  }

  @Test
  func escapedTokenQuotesShellSensitiveText() {
    #expect(SupatermShellCommand.escapedToken("hello world") == "'hello world'")
    #expect(SupatermShellCommand.escapedToken("echo 'hi'") == #"'echo '"'"'hi'"'"''"#)
  }

  @Test
  func ghosttyStartupCommandRunsScriptThroughLoginShell() {
    #expect(
      SupatermShellCommand.ghosttyStartupCommand(for: "echo hello", shellPath: "/bin/zsh")
        == "/bin/zsh -l -i -c 'echo hello'"
    )
    #expect(
      SupatermShellCommand.ghosttyStartupCommand(for: "echo hello", shellPath: "/opt/homebrew/bin/fish")
        == "/opt/homebrew/bin/fish -l -i -c 'echo hello'"
    )
    #expect(
      SupatermShellCommand.ghosttyStartupCommand(for: "echo hello", shellPath: "/opt/homebrew/bin/elvish")
        == "/opt/homebrew/bin/elvish -l -i -c 'echo hello'"
    )
    #expect(
      SupatermShellCommand.ghosttyStartupCommand(for: "echo hello", shellPath: "/opt/homebrew/bin/nu")
        == "/opt/homebrew/bin/nu -l -i -c 'echo hello'"
    )
    #expect(
      SupatermShellCommand.ghosttyStartupCommand(for: "echo 1\necho 2", shellPath: "/bin/zsh")
        == "/bin/zsh -l -i -c 'echo 1\necho 2'"
    )
  }

  @Test
  func ghosttyStartupCommandQuotesComplexScripts() {
    #expect(
      SupatermShellCommand.ghosttyStartupCommand(
        for: #"sp onboard; exec "${SHELL:-/bin/zsh}" -l"#,
        shellPath: "/bin/zsh"
      )
        == #"/bin/zsh -l -i -c 'sp onboard; exec "${SHELL:-/bin/zsh}" -l'"#
    )
  }

  @Test
  func interactiveStartupCommandLeavesTheSupportedLoginShellBehind() {
    for shellPath in [
      "/bin/bash",
      "/bin/zsh",
      "/opt/homebrew/bin/elvish",
      "/opt/homebrew/bin/fish",
      "/opt/homebrew/bin/nu",
    ] {
      #expect(
        SupatermShellCommand.interactiveStartupCommand(
          for: "echo hello",
          shellPath: shellPath
        ) == "echo hello; exec \(shellPath) -l"
      )
    }
  }

  @Test
  func installedSupportedShellsParseInteractiveStartupCommand() throws {
    var tested: Set<String> = []

    for name in ["bash", "zsh", "fish", "elvish", "nu"] {
      guard let shellPath = executablePath(named: name) else { continue }
      tested.insert(name)

      let script = SupatermShellCommand.interactiveStartupCommand(
        for: "exit 0",
        shellPath: shellPath
      )
      let process = Process()
      process.executableURL = URL(fileURLWithPath: shellPath)
      process.arguments = SupatermShellCommand.loginShellCommandArguments(for: script)
      process.standardInput = FileHandle.nullDevice
      process.standardOutput = FileHandle.nullDevice
      process.standardError = FileHandle.nullDevice
      try process.run()
      process.waitUntilExit()

      #expect(process.terminationReason == .exit)
      #expect(process.terminationStatus == 0, "\(name) rejected the startup command")
    }

    #expect(tested.contains("bash"))
    #expect(tested.contains("zsh"))
  }

  @Test
  func loginShellPathPrefersCurrentUserShell() {
    #expect(
      SupatermShellCommand.loginShellPath(
        environment: ["SHELL": "/bin/zsh"],
        currentUserShellPath: "/opt/homebrew/bin/fish"
      ) == "/opt/homebrew/bin/fish"
    )
  }

  private func executablePath(named name: String) -> String? {
    let pathDirectories =
      ProcessInfo.processInfo.environment["PATH"]?
      .split(separator: ":")
      .map(String.init) ?? []
    return (["/bin", "/usr/bin", "/opt/homebrew/bin", "/usr/local/bin"] + pathDirectories)
      .map { URL(fileURLWithPath: $0).appendingPathComponent(name).path }
      .first(where: FileManager.default.isExecutableFile)
  }
}
