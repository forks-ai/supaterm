import Foundation
import SupatermCLIShared
import Testing

extension SupatermE2ESuite {
  @Suite struct StartupCommandSafetyTests {
    @Test(.timeLimit(.minutes(5)))
    func trailingCommandsPreserveArgumentsAndReturnToTheirShell() async throws {
      try await withTestSpace { app, space in
        let runner = startupSPRunner(app, tabID: space.tab.tabID, paneID: space.tab.paneID)
        let recorder = try makeArgumentRecorder(in: space.directory)

        let tab = commandArtifacts(named: "tab", in: space)
        let tabResult = try decodeSPJSON(
          SupatermNewTabResult.self,
          from: try requireSuccessfulSPResult(
            try runner.run(
              [
                "tab", "new", "--socket", app.socketPath, "--json", "--focus",
                "--cwd", space.directory.path, "--in", space.spaceID.uuidString, "--",
                recorder.path, tab.arguments.path, tab.parentProcessID.path,
                tab.parentCommand.path,
              ] + tab.expectedArguments,
              cwd: space.directory
            )
          )
        )
        try await verifyCommandLaunch(
          app: app,
          paneID: tabResult.paneID,
          artifacts: tab
        )

        let pane = commandArtifacts(named: "pane", in: space)
        let paneResult = try decodeSPJSON(
          SupatermNewPaneResult.self,
          from: try requireSuccessfulSPResult(
            try runner.run(
              [
                "pane", "split", "right", "--socket", app.socketPath, "--json",
                "--in", tabResult.paneID.uuidString, "--cwd", space.directory.path,
                "--layout", "keep", "--", recorder.path, pane.arguments.path,
                pane.parentProcessID.path, pane.parentCommand.path,
              ] + pane.expectedArguments,
              cwd: space.directory
            )
          )
        )
        try await verifyCommandLaunch(
          app: app,
          paneID: paneResult.paneID,
          artifacts: pane
        )
      }
    }

    @Test(.timeLimit(.minutes(5)))
    func scriptsRemainShellTextForTabsAndPanes() async throws {
      try await withTestSpace { app, space in
        let runner = startupSPRunner(app, tabID: space.tab.tabID, paneID: space.tab.paneID)
        let tabOutput = space.directory.appendingPathComponent("tab-script.txt")
        let tabScript = shellTextScript(output: tabOutput, token: "tab-\(space.token)")
        let tabResult = try decodeSPJSON(
          SupatermNewTabResult.self,
          from: try requireSuccessfulSPResult(
            try runner.run(
              [
                "tab", "new", "--socket", app.socketPath, "--json", "--focus",
                "--cwd", space.directory.path, "--in", space.spaceID.uuidString,
                "--script", tabScript,
              ],
              cwd: space.directory
            )
          )
        )
        try await waitForScriptOutput(
          app: app,
          paneID: tabResult.paneID,
          output: tabOutput,
          token: "tab-\(space.token)"
        )
        try await verifyScriptShell(
          app: app,
          paneID: tabResult.paneID,
          marker: space.directory.appendingPathComponent("tab-script-follow-up.txt")
        )

        let paneOutput = space.directory.appendingPathComponent("pane-script.txt")
        let paneScript = shellTextScript(output: paneOutput, token: "pane-\(space.token)")
        let paneResult = try decodeSPJSON(
          SupatermNewPaneResult.self,
          from: try requireSuccessfulSPResult(
            try runner.run(
              [
                "pane", "split", "right", "--socket", app.socketPath, "--json",
                "--in", tabResult.paneID.uuidString, "--cwd", space.directory.path,
                "--layout", "keep", "--script", paneScript,
              ],
              cwd: space.directory
            )
          )
        )
        try await waitForScriptOutput(
          app: app,
          paneID: paneResult.paneID,
          output: paneOutput,
          token: "pane-\(space.token)"
        )
        try await verifyScriptShell(
          app: app,
          paneID: paneResult.paneID,
          marker: space.directory.appendingPathComponent("pane-script-follow-up.txt")
        )
      }
    }

    @Test(.timeLimit(.minutes(5)))
    func scriptsCanRunInteractiveShells() async throws {
      let app = try await SupatermE2EApp.launch()
      defer { app.terminate() }
      let space = try await makeTestSpace(app)
      defer { try? closeTestSpace(app, spaceID: space.spaceID) }
      let result = try makeTab(app, in: space)
      let marker = space.directory.appendingPathComponent("replacement-shell.txt")
      let replacementPane = SupatermPaneTargetRequest(paneID: result.paneID)
      do {
        try await app.waitForShellPrompt(replacementPane)
        try app.type(
          "/usr/bin/printf replacement-shell > \(marker.path)\n",
          into: replacementPane
        )
        try await app.waitUntil("the replacement shell accepts input") {
          (try? String(contentsOf: marker, encoding: .utf8)) == "replacement-shell"
        }
      } catch {
        let capture = (try? app.capture(replacementPane, scope: .scrollback)) ?? "unavailable"
        throw SupatermE2EError("\(error)\n--- replacement shell ---\n\(capture)")
      }
    }
  }
}

private func startupSPRunner(
  _ app: SupatermE2EApp,
  tabID: UUID,
  paneID: UUID
) -> SPBinaryRunner {
  SPBinaryRunner(
    executable: app.spExecutable,
    environment: app.cliEnvironment(context: app.context(tabID: tabID, paneID: paneID))
  )
}

private struct CommandSafetyArtifacts {
  let arguments: URL
  let parentProcessID: URL
  let parentCommand: URL
  let followUpParentProcessID: URL
  let followUpMarker: URL
  let followUpEnvironment: URL
  let injectionTargets: [URL]
  let secret: String
  let expectedArguments: [String]
}

private func commandArtifacts(named name: String, in space: TestSpace) -> CommandSafetyArtifacts {
  let commandSubstitution = space.directory.appendingPathComponent("\(name)-command-substitution")
  let backtickSubstitution = space.directory.appendingPathComponent("\(name)-backtick-substitution")
  let statementBreak = space.directory.appendingPathComponent("\(name)-statement-break")
  let newlineBreak = space.directory.appendingPathComponent("\(name)-newline-break")
  let injectionTargets = [commandSubstitution, backtickSubstitution, statementBreak, newlineBreak]
  let secret = "startup-secret-\(name)-\(space.token)"
  return CommandSafetyArtifacts(
    arguments: space.directory.appendingPathComponent("\(name)-arguments.bin"),
    parentProcessID: space.directory.appendingPathComponent("\(name)-parent-pid.txt"),
    parentCommand: space.directory.appendingPathComponent("\(name)-parent-command.txt"),
    followUpParentProcessID: space.directory.appendingPathComponent("\(name)-follow-up-parent-pid.txt"),
    followUpMarker: space.directory.appendingPathComponent("\(name)-follow-up.txt"),
    followUpEnvironment: space.directory.appendingPathComponent("\(name)-follow-up-environment.txt"),
    injectionTargets: injectionTargets,
    secret: secret,
    expectedArguments: [
      "",
      "plain",
      "white space",
      "line one\nline two",
      "single'quote",
      "double\"quote",
      "bang!",
      "dollar$HOME",
      "unicode-👩🏽‍💻-東京",
      "wild*card?[",
      "pipe|amp&redirect>",
      "back\\slash",
      "$(/usr/bin/touch \(commandSubstitution.path))",
      "`/usr/bin/touch \(backtickSubstitution.path)`",
      "; /usr/bin/touch \(statementBreak.path); :",
      "newline\n/usr/bin/touch \(newlineBreak.path)\n:",
      "--looks-like-an-option",
      secret,
    ]
  )
}

private func makeArgumentRecorder(in directory: URL) throws -> URL {
  let recorder = directory.appendingPathComponent("record-arguments.sh")
  let contents = """
    #!/bin/sh
    output=$1
    parent=$2
    parent_command=$3
    shift 3
    /usr/bin/printf '%s' "$PPID" > "$parent"
    /bin/ps -p "$PPID" -o command= > "$parent_command"
    {
      /usr/bin/printf '%s\\0' "$#"
      for argument in "$@"; do
        /usr/bin/printf '%s\\0' "$argument"
      done
    } > "$output"
    """
  try contents.write(to: recorder, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes(
    [.posixPermissions: 0o700],
    ofItemAtPath: recorder.path
  )
  return recorder
}

private func verifyCommandLaunch(
  app: SupatermE2EApp,
  paneID: UUID,
  artifacts: CommandSafetyArtifacts
) async throws {
  let pane = SupatermPaneTargetRequest(paneID: paneID)
  do {
    try await app.waitUntil("the argument recorder completes") {
      (try? recordedArguments(from: artifacts.arguments)) != nil
    }
  } catch {
    let capture = (try? app.capture(pane, scope: .scrollback)) ?? "unavailable"
    throw SupatermE2EError("\(error)\n--- startup pane ---\n\(capture)")
  }
  #expect(try recordedArguments(from: artifacts.arguments) == artifacts.expectedArguments)

  let marker = "follow-up-\(paneID.uuidString.lowercased())"
  let probe = [
    "/bin/sh",
    "-c",
    "/usr/bin/printf '%s' \"$PPID\" > \"$1\"; /usr/bin/env > \"$4\"; /usr/bin/printf '%s' \"$2\" > \"$3\"",
    "sh",
    artifacts.followUpParentProcessID.path,
    marker,
    artifacts.followUpMarker.path,
    artifacts.followUpEnvironment.path,
  ].map(SupatermShellCommand.escapedToken).joined(separator: " ")
  try app.type("\(probe)\n", into: pane)
  try await app.waitUntil("the startup shell runs a follow-up command") {
    (try? String(contentsOf: artifacts.followUpMarker, encoding: .utf8)) == marker
  }

  let startupParent = try String(contentsOf: artifacts.parentProcessID, encoding: .utf8)
  let startupParentCommand = try String(contentsOf: artifacts.parentCommand, encoding: .utf8)
    .trimmingCharacters(in: .whitespacesAndNewlines)
  let followUpParent = try String(contentsOf: artifacts.followUpParentProcessID, encoding: .utf8)
  let followUpEnvironment = try String(contentsOf: artifacts.followUpEnvironment, encoding: .utf8)
  #expect(startupParent.isEmpty == false)
  #expect(startupParentCommand == "-\(SupatermShellCommand.loginShellPath())")
  #expect(followUpParent == startupParent)
  #expect(!followUpEnvironment.contains(artifacts.secret))
  #expect(!followUpEnvironment.contains("SUPATERM_STARTUP_"))
  for target in artifacts.injectionTargets {
    #expect(FileManager.default.fileExists(atPath: target.path) == false)
  }
  try await app.waitUntil("the startup transport is removed") {
    try startupTransportDirectories(processIdentifier: app.processIdentifier).isEmpty
  }
}

private func startupTransportDirectories(processIdentifier: pid_t) throws -> [URL] {
  let prefix = "supaterm-startup-\(processIdentifier)-"
  return try FileManager.default.contentsOfDirectory(
    at: URL(fileURLWithPath: "/private/tmp", isDirectory: true),
    includingPropertiesForKeys: nil,
    options: [.skipsHiddenFiles]
  ).filter { $0.lastPathComponent.hasPrefix(prefix) }
}

private func recordedArguments(from url: URL) throws -> [String] {
  let data = try Data(contentsOf: url)
  var fields = data.split(separator: 0, omittingEmptySubsequences: false)
  guard fields.last?.isEmpty == true else {
    throw SupatermE2EError("The argument record is incomplete.")
  }
  fields.removeLast()
  guard let countField = fields.first,
    let countText = String(bytes: countField, encoding: .utf8),
    let count = Int(countText)
  else {
    throw SupatermE2EError("The argument record has no valid count.")
  }
  let arguments = try fields.dropFirst().map { field in
    guard let argument = String(bytes: field, encoding: .utf8) else {
      throw SupatermE2EError("The argument record is not UTF-8.")
    }
    return argument
  }
  guard arguments.count == count else {
    throw SupatermE2EError("The argument record has \(arguments.count) of \(count) fields.")
  }
  return arguments
}

private func shellTextScript(output: URL, token: String) -> String {
  let longToken = shellTextToken(token)
  return "/usr/bin/printf '%s\\n' '\(longToken)-first' > '\(output.path)' && "
    + "/usr/bin/printf '%s\\n' '\(token)-second' >> '\(output.path)'"
}

private func shellTextToken(_ token: String) -> String {
  "\(token)-\(String(repeating: "x", count: 2_048))"
}

private func waitForScriptOutput(
  app: SupatermE2EApp,
  paneID: UUID,
  output: URL,
  token: String
) async throws {
  let expected = "\(shellTextToken(token))-first\n\(token)-second\n"
  do {
    try await app.waitUntil("the shell script writes both commands") {
      (try? String(contentsOf: output, encoding: .utf8)) == expected
    }
  } catch {
    let capture =
      (try? app.capture(SupatermPaneTargetRequest(paneID: paneID), scope: .scrollback))
      ?? "unavailable"
    throw SupatermE2EError("\(error)\n--- script pane ---\n\(capture)")
  }
}

private func verifyScriptShell(
  app: SupatermE2EApp,
  paneID: UUID,
  marker: URL
) async throws {
  let pane = SupatermPaneTargetRequest(paneID: paneID)
  let expected = "script-follow-up-\(paneID.uuidString.lowercased())"
  let command = ["/usr/bin/printf", expected]
    .map(SupatermShellCommand.escapedToken)
    .joined(separator: " ")
  do {
    try app.type("\(command) > \(SupatermShellCommand.escapedToken(marker.path))\n", into: pane)
    try await app.waitUntil("the login shell accepts input after the script") {
      (try? String(contentsOf: marker, encoding: .utf8)) == expected
    }
  } catch {
    let capture = (try? app.capture(pane, scope: .scrollback)) ?? "unavailable"
    throw SupatermE2EError("\(error)\n--- script follow-up ---\n\(capture)")
  }
}
