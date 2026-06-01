import Foundation

public enum SupatermShellCommand {
  public static let startupShell = "/bin/zsh"

  public static func ghosttyStartupCommand(
    for script: String,
    preservesShellIntegrationEnvironment: Bool = false
  ) -> String {
    let flags = preservesShellIntegrationEnvironment ? "-flc" : "-lc"
    return "\(startupShell) \(flags) \(escapedToken(script))"
  }

  public static func interactiveStartupCommand(for command: String) -> String {
    [
      command,
      #"shell="${SHELL:-/bin/zsh}""#,
      #"[ -x "$shell" ] || shell="/bin/zsh""#,
      #"if "$shell" -l -c 'exit 0' >/dev/null 2>&1; then exec "$shell" -l; fi"#,
      #"exec "$shell""#,
    ].joined(separator: "; ")
  }

  public static func escapedToken(_ token: String) -> String {
    guard !token.isEmpty else { return "''" }

    let safeScalars = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789@%_+=:,./-")
    if token.unicodeScalars.allSatisfy(safeScalars.contains) {
      return token
    }

    return "'\(token.replacingOccurrences(of: "'", with: "'\"'\"'"))'"
  }
}
