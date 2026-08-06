import Foundation
import Testing

@testable import SupatermCLIShared

struct SupatermSSHCommandTests {
  @Test
  func dropsForwardedEnvironmentOptionsAndTheResolvedExecutablePath() {
    let command = SupatermSSHCommand.commandLine(forArguments: [
      "/usr/bin/ssh",
      "-o", "SendEnv=COLORTERM",
      "-o", "SendEnv=TERM_PROGRAM",
      "-o", "SendEnv=TERM_PROGRAM_VERSION",
      "-o", "SetEnv=PRODUCT=custom",
      "-p", "2222",
      "dev@example.com",
    ])

    #expect(command == "ssh -o SetEnv=PRODUCT=custom -p 2222 dev@example.com")
  }

  @Test
  func quotesArgumentsThatNeedIt() {
    let command = SupatermSSHCommand.commandLine(forArguments: [
      "ssh", "example.com", "echo hi",
    ])

    #expect(command == "ssh example.com 'echo hi'")
  }

  @Test
  func rejectsNonSSHAndBareInvocations() {
    #expect(SupatermSSHCommand.commandLine(forArguments: ["/bin/fish", "-l"]) == nil)
    #expect(SupatermSSHCommand.commandLine(forArguments: ["ssh"]) == nil)
    #expect(SupatermSSHCommand.commandLine(forArguments: []) == nil)
  }
}
