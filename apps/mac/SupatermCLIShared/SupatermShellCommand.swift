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
