import Foundation
import SupatermCLIShared
import Testing

struct SPAgentHookCommandTests {
  @Test
  func installHookClaudeWritesManagedHooksSilently() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let install = try cli.run(["agent", "install-hook", "claude"])

    #expect(install == SPCLIResult(exitCode: 0, stdout: "", stderr: ""))
    let hooks = try claudeHooks(in: cli)
    #expect(
      Set(hooks.keys) == [
        "Notification", "PostToolUse", "PreToolUse", "SessionEnd", "SessionStart", "Stop",
        "SubagentStart", "SubagentStop", "UserPromptSubmit",
      ]
    )
    #expect(claudeCommands(in: hooks).allSatisfy { $0 == SupatermClaudeHookSettings.command })
    #expect(claudeCommands(in: hooks).count == hooks.count)
  }

  @Test
  func installHookClaudeIsIdempotentAndPreservesUnrelatedSettings() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    try writeClaudeSettings(
      """
      {
        "theme": "dark",
        "hooks": {
          "Notification": [
            {"hooks": [{"command": "echo keep", "timeout": 30, "type": "command"}]}
          ]
        }
      }
      """,
      in: cli
    )

    #expect(try cli.run(["agent", "install-hook", "claude"]).exitCode == 0)
    #expect(try cli.run(["agent", "install-hook", "claude"]).exitCode == 0)

    let object = try claudeSettingsObject(in: cli)
    let hooks = try #require(object["hooks"] as? [String: Any])
    #expect(object["theme"] as? String == "dark")
    #expect(claudeCommands(in: hooks).filter { $0 == SupatermClaudeHookSettings.command }.count == 9)
    #expect(claudeCommands(in: hooks).contains("echo keep"))
  }

  @Test
  func removeHookClaudeDropsManagedHooksAndKeepsTheRest() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    try writeClaudeSettings(
      """
      {
        "theme": "dark",
        "hooks": {
          "Notification": [
            {"hooks": [{"command": "echo keep", "timeout": 30, "type": "command"}]}
          ]
        }
      }
      """,
      in: cli
    )
    #expect(try cli.run(["agent", "install-hook", "claude"]).exitCode == 0)

    let remove = try cli.run(["agent", "remove-hook", "claude"])

    #expect(remove == SPCLIResult(exitCode: 0, stdout: "", stderr: ""))
    let object = try claudeSettingsObject(in: cli)
    #expect(object["theme"] as? String == "dark")
    #expect(claudeCommands(in: try #require(object["hooks"] as? [String: Any])) == ["echo keep"])
  }

  @Test
  func installHookClaudeFailsWithoutOverwritingInvalidSettings() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let invalidJSON = #"{ "hooks":"#
    try writeClaudeSettings(invalidJSON, in: cli)

    let install = try cli.run(["agent", "install-hook", "claude"])

    #expect(
      install
        == SPCLIResult(
          exitCode: 1,
          stdout: "",
          stderr: "Claude settings must be valid JSON before Supaterm can install hooks.\n"
        )
    )
    #expect(try String(contentsOf: cli.claudeSettingsURL, encoding: .utf8) == invalidJSON)
  }

  @Test
  func removeHookClaudeSucceedsWithoutAnySettingsFile() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let remove = try cli.run(["agent", "remove-hook", "claude"])

    #expect(remove == SPCLIResult(exitCode: 0, stdout: "", stderr: ""))
    #expect(!FileManager.default.fileExists(atPath: cli.claudeSettingsURL.path))
  }

  @Test(arguments: [["agent", "install-hook"], ["agent", "remove-hook"], ["agent"]])
  func agentHookParentCommandsPrintHelp(arguments: [String]) throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let result = try cli.run(arguments)

    #expect(result.exitCode == 0)
    #expect(result.stdout.contains("USAGE:"))
    #expect(result.stderr.isEmpty)
  }
}

private func writeClaudeSettings(_ contents: String, in cli: SPCLIHarness) throws {
  try FileManager.default.createDirectory(
    at: cli.claudeSettingsURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try Data(contents.utf8).write(to: cli.claudeSettingsURL)
}

private func claudeSettingsObject(in cli: SPCLIHarness) throws -> [String: Any] {
  let data = try Data(contentsOf: cli.claudeSettingsURL)
  return try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
}

private func claudeHooks(in cli: SPCLIHarness) throws -> [String: Any] {
  try #require(try claudeSettingsObject(in: cli)["hooks"] as? [String: Any])
}

private func claudeCommands(in hooks: [String: Any]) -> [String] {
  hooks.keys.sorted()
    .flatMap { (hooks[$0] as? [[String: Any]]) ?? [] }
    .flatMap { ($0["hooks"] as? [[String: Any]]) ?? [] }
    .compactMap { $0["command"] as? String }
}
