import Foundation
import Testing

@testable import SupatermCLIShared

struct SupatermSSHCommandTests {
  private static let cliPath = "/Applications/supaterm.app/Contents/MacOS/sp"

  @Test
  func routesTheInheritedSessionThroughTheBundledCLI() {
    let command = SupatermSSHCommand.commandLine(
      forArguments: [
        "/usr/bin/ssh",
        "-o", "SendEnv=COLORTERM",
        "-o", "SendEnv=TERM_PROGRAM",
        "-o", "SendEnv=TERM_PROGRAM_VERSION",
        "-o", "SetEnv=PRODUCT=custom",
        "-p", "2222",
        "dev@example.com",
      ],
      cliPath: Self.cliPath
    )

    #expect(command == "\(Self.cliPath) ssh -- -o SetEnv=PRODUCT=custom -p 2222 dev@example.com")
  }

  @Test
  func fallsBackToBareSSHWithoutTheBundledCLI() {
    let command = SupatermSSHCommand.commandLine(
      forArguments: ["/usr/bin/ssh", "-p", "2222", "dev@example.com"],
      cliPath: nil
    )

    #expect(command == "ssh -p 2222 dev@example.com")
  }

  @Test
  func quotesOptionValuesThatNeedIt() {
    let command = SupatermSSHCommand.commandLine(
      forArguments: ["ssh", "-o", "ProxyCommand=nc %h %p", "example.com"],
      cliPath: nil
    )

    #expect(command == "ssh -o 'ProxyCommand=nc %h %p' example.com")
  }

  @Test
  func keepsFlagsClusteredWithTheirValue() {
    let command = SupatermSSHCommand.commandLine(
      forArguments: ["ssh", "-tt", "-p2222", "-4", "example.com"],
      cliPath: nil
    )

    #expect(command == "ssh -tt -p2222 -4 example.com")
  }

  @Test
  func refusesInvocationsThatCarryARemoteCommand() {
    #expect(
      SupatermSSHCommand.commandLine(
        forArguments: ["ssh", "example.com", "echo hi"],
        cliPath: nil
      ) == nil
    )
    #expect(
      SupatermSSHCommand.commandLine(
        forArguments: ["ssh", "-o", "ControlPath=none", "example.com", "git-upload-pack '/repo'"],
        cliPath: nil
      ) == nil
    )
  }

  @Test
  func refusesInvocationsThatOpenNoSession() {
    #expect(
      SupatermSSHCommand.commandLine(
        forArguments: ["ssh", "-N", "-L", "8080:localhost:8080", "example.com"],
        cliPath: nil
      ) == nil
    )
    #expect(
      SupatermSSHCommand.commandLine(
        forArguments: ["ssh", "-f", "-D", "1080", "example.com"],
        cliPath: nil
      ) == nil
    )
    #expect(
      SupatermSSHCommand.commandLine(
        forArguments: ["ssh", "-W", "example.com:22", "jump.example.com"],
        cliPath: nil
      ) == nil
    )
  }

  @Test
  func keepsForwardingOptionsThatStillOpenASession() {
    let command = SupatermSSHCommand.commandLine(
      forArguments: ["ssh", "-L", "8080:localhost:8080", "example.com"],
      cliPath: nil
    )

    #expect(command == "ssh -L 8080:localhost:8080 example.com")
  }

  @Test
  func rejectsNonSSHAndIncompleteInvocations() {
    #expect(SupatermSSHCommand.commandLine(forArguments: ["/bin/fish", "-l"], cliPath: nil) == nil)
    #expect(SupatermSSHCommand.commandLine(forArguments: ["ssh"], cliPath: nil) == nil)
    #expect(SupatermSSHCommand.commandLine(forArguments: ["ssh", "-p"], cliPath: nil) == nil)
    #expect(SupatermSSHCommand.commandLine(forArguments: [], cliPath: nil) == nil)
  }
}
