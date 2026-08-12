import CustomDump
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
  func escapedCommandPreservesArgumentBoundaries() {
    expectNoDifference(
      SupatermShellCommand.escapedCommand([
        "tool",
        "",
        "two words",
        "echo 'hi'",
        "$HOME",
      ]),
      #"tool '' 'two words' 'echo '"'"'hi'"'"'' '$HOME'"#
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

}
