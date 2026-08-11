import Foundation
import Testing

@testable import SupatermCLIShared

struct SupatermSSHCommandTests {
  private static let cliPath = "/Applications/supaterm.app/Contents/MacOS/sp"

  @Test
  func routesTheInheritedSessionThroughTheBundledCLI() {
    let arguments = inheritedArguments(
      arguments: [
        "/usr/bin/ssh",
        "-o", "SendEnv=COLORTERM",
        "-o", "SendEnv=TERM_PROGRAM",
        "-o", "SendEnv=TERM_PROGRAM_VERSION",
        "-o", "SetEnv=PRODUCT=custom",
        "-p", "2222",
        "dev@example.com",
      ],
      terminalType: "xterm-custom",
      cliPath: Self.cliPath
    )

    #expect(
      arguments
        == [
          "/usr/bin/env", Self.cliPath, "ssh", "--term", "xterm-custom", "--ssh", "/usr/bin/ssh",
          "--", "-o", "SetEnv=PRODUCT=custom", "-p", "2222", "dev@example.com",
        ]
    )
  }

  @Test
  func preservesCustomSSHExecutableAndTerminalType() {
    let arguments = inheritedArguments(
      arguments: ["/opt/custom/client"] + SupatermSSHCommand.forwardedEnvironmentOptions
        + ["dev@example.com"],
      terminalType: "vt100-custom",
      cliPath: Self.cliPath
    )

    #expect(
      arguments
        == [
          "/usr/bin/env", Self.cliPath, "ssh", "--term", "vt100-custom", "--ssh",
          "/opt/custom/client", "--", "dev@example.com",
        ]
    )
  }

  @Test
  func stripsOnlyTheInjectedLeadingForwardingOptions() {
    let arguments = inheritedArguments(
      arguments: ["/usr/bin/ssh"] + SupatermSSHCommand.forwardedEnvironmentOptions
        + ["-o", "SendEnv=COLORTERM", "dev@example.com"],
      cliPath: Self.cliPath
    )

    #expect(
      arguments
        == [
          "/usr/bin/env", Self.cliPath, "ssh", "--ssh", "/usr/bin/ssh", "--", "-o",
          "SendEnv=COLORTERM", "dev@example.com",
        ]
    )
  }

  @Test
  func preservesOptionValuesThatContainSpaces() {
    let arguments = inheritedArguments(
      arguments: ["ssh", "-o", "ProxyCommand=nc %h %p", "example.com"]
    )

    #expect(
      arguments
        == [
          "/usr/bin/env", Self.cliPath, "ssh", "--ssh", "ssh", "--", "-o",
          "ProxyCommand=nc %h %p", "example.com",
        ]
    )
  }

  @Test
  func keepsFlagsClusteredWithTheirValue() {
    let arguments = inheritedArguments(
      arguments: ["ssh", "-tt", "-p2222", "-4", "example.com"]
    )

    #expect(
      arguments
        == [
          "/usr/bin/env", Self.cliPath, "ssh", "--ssh", "ssh", "--", "-tt", "-p2222", "-4",
          "example.com",
        ]
    )
  }

  @Test
  func refusesInvocationsThatCarryARemoteCommand() {
    #expect(inheritedArguments(arguments: ["ssh", "example.com", "echo hi"]) == nil)
    #expect(
      inheritedArguments(
        arguments: ["ssh"] + SupatermSSHCommand.forwardedEnvironmentOptions
          + ["example.com", "-o", "SendEnv=COLORTERM"]
      ) == nil
    )
    #expect(
      inheritedArguments(
        arguments: ["ssh", "-o", "ControlPath=none", "example.com", "git-upload-pack '/repo'"]
      ) == nil
    )
  }

  @Test
  func refusesInvocationsThatOpenNoSession() {
    #expect(
      inheritedArguments(arguments: ["ssh", "-N", "-L", "8080:localhost:8080", "example.com"])
        == nil
    )
    #expect(inheritedArguments(arguments: ["ssh", "-f", "-D", "1080", "example.com"]) == nil)
    #expect(inheritedArguments(arguments: ["ssh", "-W", "example.com:22", "jump.example.com"]) == nil)
  }

  @Test
  func keepsForwardingOptionsThatStillOpenASession() {
    let arguments = inheritedArguments(
      arguments: ["ssh", "-L", "8080:localhost:8080", "example.com"]
    )

    #expect(
      arguments
        == [
          "/usr/bin/env", Self.cliPath, "ssh", "--ssh", "ssh", "--", "-L",
          "8080:localhost:8080", "example.com",
        ]
    )
  }

  @Test
  func rejectsUnidentifiedCustomExecutablesAndIncompleteInvocations() {
    #expect(inheritedArguments(arguments: ["/opt/custom/client", "example.com"]) == nil)
    #expect(inheritedArguments(arguments: ["/bin/fish", "-l"]) == nil)
    #expect(inheritedArguments(arguments: ["ssh"]) == nil)
    #expect(inheritedArguments(arguments: ["ssh", "-p"]) == nil)
    #expect(inheritedArguments(arguments: []) == nil)
  }

  private func inheritedArguments(
    arguments: [String],
    terminalType: String? = nil,
    cliPath: String = Self.cliPath
  ) -> [String]? {
    SupatermSSHCommand.inheritedArguments(
      forArguments: arguments,
      terminalType: terminalType,
      cliPath: cliPath
    )
  }
}
