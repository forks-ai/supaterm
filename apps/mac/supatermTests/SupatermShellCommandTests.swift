import CustomDump
import Foundation
import Testing

@testable import SupatermCLIShared

struct SupatermShellCommandTests {
  @Test
  func escapedTokenLeavesSafeTokensUnquoted() {
    expectNoDifference(
      SupatermShellCommand.escapedToken("abcXYZ09@%_+=:,./-"),
      "abcXYZ09@%_+=:,./-"
    )
  }

  @Test
  func escapedTokenQuotesShellSensitiveText() {
    expectNoDifference(
      SupatermShellCommand.escapedToken("hello world"),
      "'hello world'"
    )
    expectNoDifference(
      SupatermShellCommand.escapedToken("echo 'hi'"),
      #"'echo '"'"'hi'"'"''"#
    )
  }

  @Test
  func loginShellCommandArgumentsKeepTheScriptInOneArgument() {
    expectNoDifference(
      SupatermShellCommand.loginShellCommandArguments(for: "printf '%s\\n' hello; exit"),
      ["-l", "-i", "-c", "printf '%s\\n' hello; exit"]
    )
  }

  @Test
  func loginShellPathPrefersTheCurrentUsersAbsoluteExecutable() {
    expectNoDifference(
      SupatermShellCommand.loginShellPath(
        environment: ["SHELL": "/bin/zsh"],
        currentUserShellPath: "/bin/sh"
      ),
      "/bin/sh"
    )
  }

  @Test
  func loginShellPathUsesTheEnvironmentWhenTheCurrentUserShellIsInvalid() {
    for invalidPath in ["bin/zsh", "/does/not/exist", "/bin"] {
      expectNoDifference(
        SupatermShellCommand.loginShellPath(
          environment: ["SHELL": "/bin/sh"],
          currentUserShellPath: invalidPath
        ),
        "/bin/sh"
      )
    }
  }

  @Test
  func loginShellPathRejectsAnInvalidEnvironmentShell() {
    for invalidPath in ["bin/sh", "/does/not/exist", "/bin"] {
      expectNoDifference(
        SupatermShellCommand.loginShellPath(
          environment: ["SHELL": invalidPath],
          currentUserShellPath: nil
        ),
        "/bin/zsh"
      )
    }
  }

  @Test
  func loginShellPathTrimsAnAbsoluteExecutable() {
    expectNoDifference(
      SupatermShellCommand.loginShellPath(
        environment: [:],
        currentUserShellPath: "  /bin/sh\n"
      ),
      "/bin/sh"
    )
  }

  @Test
  func availableShellsRunStartupPathAndRemainLoginShells() throws {
    for shellPath in [
      "/bin/bash",
      "/bin/csh",
      "/bin/dash",
      "/bin/ksh",
      "/bin/sh",
      "/bin/tcsh",
      "/bin/zsh",
      "/opt/homebrew/bin/elvish",
      "/opt/homebrew/bin/fish",
      "/usr/local/bin/elvish",
      "/usr/local/bin/fish",
    ].filter(FileManager.default.isExecutableFile(atPath:)) {
      try verifyLoginShellStartup(shellPath)
    }
  }
}

private func verifyLoginShellStartup(_ shellPath: String) throws {
  #expect(FileManager.default.isExecutableFile(atPath: shellPath))
  let directoryURL = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
    .appendingPathComponent("supaterm-shell-test-\(UUID().uuidString.lowercased())", isDirectory: true)
  try FileManager.default.createDirectory(at: directoryURL, withIntermediateDirectories: false)
  defer { try? FileManager.default.removeItem(at: directoryURL) }
  let launchedURL = directoryURL.appendingPathComponent("launched")
  let followUpURL = directoryURL.appendingPathComponent("follow-up")
  let loginCommandURL = directoryURL.appendingPathComponent("login-command")
  let recorderURL = directoryURL.appendingPathComponent("recorder")
  let recorder = """
    #!/bin/sh
    /bin/ps -p "$PPID" -o command= > "\(loginCommandURL.path)"
    /usr/bin/printf launched > "\(launchedURL.path)"
    """
  try recorder.write(to: recorderURL, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: recorderURL.path)
  let prepared = try SupatermTerminalStartup.script(recorderURL.path).prepare(
    cliPath: nil,
    shellPath: shellPath,
    temporaryDirectory: directoryURL
  )
  defer { prepared.cleanupToken?.cleanup() }
  let transportDirectoryURL = try #require(prepared.cleanupDirectoryURL)

  let input = Pipe()
  let process = Process()
  process.executableURL = URL(fileURLWithPath: "/bin/bash")
  process.arguments = [
    "--noprofile",
    "--norc",
    "-c",
    #"exec -l -- "$@""#,
    "bash",
    shellPath,
  ]
  process.environment = [
    "HOME": directoryURL.path,
    "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
    "ZDOTDIR": directoryURL.path,
  ]
  process.standardInput = input
  process.standardOutput = FileHandle.nullDevice
  process.standardError = FileHandle.nullDevice
  try process.run()
  try input.fileHandleForWriting.write(
    contentsOf: Data(
      "\(prepared.initialInput)/usr/bin/printf follow-up > \(followUpURL.path)\nexit\n".utf8
    )
  )
  try input.fileHandleForWriting.close()
  process.waitUntilExit()

  #expect(process.terminationStatus == 0)
  #expect(try String(contentsOf: launchedURL, encoding: .utf8) == "launched")
  #expect(try String(contentsOf: followUpURL, encoding: .utf8) == "follow-up")
  #expect(!FileManager.default.fileExists(atPath: transportDirectoryURL.path))
  #expect(
    try String(contentsOf: loginCommandURL, encoding: .utf8)
      .trimmingCharacters(in: .whitespacesAndNewlines) == "-\(shellPath)"
  )
}
