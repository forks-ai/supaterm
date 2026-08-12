import Foundation
import SupatermCLIShared
import Testing

extension SupatermE2ESuite {
  @Suite struct StartupCommandSafetyTests {
    @Test(.timeLimit(.minutes(5)))
    func trailingCommandsPreserveArgumentsAndCloseOnExit() async throws {
      try await withTestSpace { app, space in
        let recorder = try makeArgumentRecorder(in: space.directory)
        var environment = app.cliEnvironment(
          context: app.context(tabID: space.tab.tabID, paneID: space.tab.paneID)
        )
        environment["PATH"] = [space.directory.path, environment["PATH"]]
          .compactMap { $0 }
          .joined(separator: ":")
        let runner = SPBinaryRunner(executable: app.spExecutable, environment: environment)

        let tab = commandArtifacts(named: "tab", in: space)
        let tabResult = try decodeSPJSON(
          SupatermNewTabResult.self,
          from: try requireSuccessfulSPResult(
            try runner.run(
              [
                "tab", "new", "--socket", app.socketPath, "--json", "--focus",
                "--cwd", space.directory.path, "--in", space.spaceID.uuidString, "--",
                recorder.lastPathComponent, tab.arguments.path,
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
        try await app.waitUntil("the direct command tab is removed") {
          try app.debugTab(tabResult.tabID) == nil
        }

        let pane = commandArtifacts(named: "pane", in: space)
        let paneResult = try decodeSPJSON(
          SupatermNewPaneResult.self,
          from: try requireSuccessfulSPResult(
            try runner.run(
              [
                "pane", "split", "right", "--socket", app.socketPath, "--json",
                "--in", space.tab.paneID.uuidString, "--cwd", space.directory.path,
                "--layout", "keep", "--", recorder.lastPathComponent, pane.arguments.path,
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
        try await app.waitUntil("the direct command pane is removed") {
          try app.debugPane(paneResult.paneID) == nil
        }
      }
    }

    @Test(.timeLimit(.minutes(5)))
    func scriptsRemainShellTextForTabsAndPanes() async throws {
      try await withTestSpace { app, space in
        let runner = startupSPRunner(app, tabID: space.tab.tabID, paneID: space.tab.paneID)
        let shellProcessIDRecorder = try makeShellProcessIDRecorder(in: space.directory)
        let tabOutput = space.directory.appendingPathComponent("tab-script.txt")
        let tabShellProcess = ShellProcessArtifacts(
          recorder: shellProcessIDRecorder,
          startup: space.directory.appendingPathComponent("tab-script-shell-pid.txt"),
          followUp: space.directory.appendingPathComponent("tab-script-follow-up-shell-pid.txt")
        )
        let tabToken = "tab-\(space.token)"
        let tabScript = shellTextScript(
          output: tabOutput,
          shellProcess: tabShellProcess,
          token: tabToken
        )
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
          token: tabToken
        )
        try await app.waitForCapture(
          SupatermPaneTargetRequest(paneID: tabResult.paneID),
          contains: tabToken
        )
        try await verifyScriptShell(
          app: app,
          paneID: tabResult.paneID,
          shellProcess: tabShellProcess,
          marker: space.directory.appendingPathComponent("tab-script-follow-up.txt")
        )

        let paneOutput = space.directory.appendingPathComponent("pane-script.txt")
        let paneShellProcess = ShellProcessArtifacts(
          recorder: shellProcessIDRecorder,
          startup: space.directory.appendingPathComponent("pane-script-shell-pid.txt"),
          followUp: space.directory.appendingPathComponent("pane-script-follow-up-shell-pid.txt")
        )
        let paneToken = "pane-\(space.token)"
        let paneScript = shellTextScript(
          output: paneOutput,
          shellProcess: paneShellProcess,
          token: paneToken
        )
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
          token: paneToken
        )
        try await app.waitForCapture(
          SupatermPaneTargetRequest(paneID: paneResult.paneID),
          contains: paneToken
        )
        try await verifyScriptShell(
          app: app,
          paneID: paneResult.paneID,
          shellProcess: paneShellProcess,
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
        try app.type("\(makeMarkerCommand(value: "replacement-shell", marker: marker))\n", into: replacementPane)
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
  let injectionTargets: [URL]
  let expectedArguments: [String]
}

private struct ShellProcessArtifacts {
  let recorder: URL
  let startup: URL
  let followUp: URL
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
    injectionTargets: injectionTargets,
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
    shift
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

  for target in artifacts.injectionTargets {
    #expect(FileManager.default.fileExists(atPath: target.path) == false)
  }
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

private func shellTextScript(
  output: URL,
  shellProcess: ShellProcessArtifacts,
  token: String
) -> String {
  let longToken = shellTextToken(token)
  return shellProcessIDCommand(recorder: shellProcess.recorder, output: shellProcess.startup) + " && "
    + "/usr/bin/printf '%s\\n' '\(longToken)-first' > '\(output.path)' && "
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
  shellProcess: ShellProcessArtifacts,
  marker: URL
) async throws {
  let pane = SupatermPaneTargetRequest(paneID: paneID)
  let expected = "script-follow-up-\(paneID.uuidString.lowercased())"
  let markerCommand = try makeMarkerCommand(value: expected, marker: marker)
  let command =
    shellProcessIDCommand(
      recorder: shellProcess.recorder,
      output: shellProcess.followUp
    ) + " && " + markerCommand
  do {
    try app.type("\(command)\n", into: pane)
    try await app.waitUntil("the login shell accepts input after the script") {
      (try? String(contentsOf: marker, encoding: .utf8)) == expected
    }
  } catch {
    let capture = (try? app.capture(pane, scope: .scrollback)) ?? "unavailable"
    throw SupatermE2EError("\(error)\n--- script follow-up ---\n\(capture)")
  }

  let startupProcessID = try String(contentsOf: shellProcess.startup, encoding: .utf8)
  let followUpProcessID = try String(contentsOf: shellProcess.followUp, encoding: .utf8)
  #expect(startupProcessID.isEmpty == false)
  #expect(followUpProcessID == startupProcessID)
}

private func makeShellProcessIDRecorder(in directory: URL) throws -> URL {
  let recorder = directory.appendingPathComponent("record-shell-process-id.sh")
  try """
  #!/bin/sh
  /usr/bin/printf '%s' "$PPID" > "$1"
  """.write(to: recorder, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: recorder.path)
  return recorder
}

private func shellProcessIDCommand(recorder: URL, output: URL) -> String {
  SupatermShellCommand.escapedCommand([recorder.path, output.path])
}

private func makeMarkerCommand(value: String, marker: URL) throws -> String {
  let writer = marker.deletingPathExtension().appendingPathExtension("sh")
  try """
  #!/bin/sh
  /usr/bin/printf '%s' "$1" > "$2"
  """.write(to: writer, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: writer.path)
  return try shellNeutralCommand([writer.path, value, marker.path])
}

private func shellNeutralCommand(_ arguments: [String]) throws -> String {
  guard arguments.allSatisfy({ SupatermShellCommand.escapedToken($0) == $0 }) else {
    throw SupatermE2EError("The shell-neutral command contains an unsafe path or argument.")
  }
  return arguments.joined(separator: " ")
}
