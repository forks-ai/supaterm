public enum SupatermSSHCommand {
  public static let program = "ssh"
  public static let term = "xterm-256color"
  private static let forwardedEnvironmentVariables = [
    "COLORTERM",
    "TERM_PROGRAM",
    "TERM_PROGRAM_VERSION",
  ]

  public static var forwardedEnvironmentOptions: [String] {
    forwardedEnvironmentVariables.flatMap { ["-o", "SendEnv=\($0)"] }
  }
}
