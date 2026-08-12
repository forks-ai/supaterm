import Darwin
import Foundation

public enum SupatermShellCommand {
  public static var defaultExecutableSearchPath: String { _PATH_DEFPATH }

  public static func loginShellCommandArguments(for command: String) -> [String] {
    ["-l", "-i", "-c", command]
  }

  public static func loginShellPath(
    environment: [String: String] = ProcessInfo.processInfo.environment,
    currentUserShellPath: String? = currentUserShellPath()
  ) -> String {
    executableShellPath(currentUserShellPath)
      ?? executableShellPath(environment["SHELL"])
      ?? executableShellPath("/bin/zsh")
      ?? "/bin/sh"
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

  public static func currentUserShellPath() -> String? {
    guard let entry = getpwuid(getuid()), let shell = entry.pointee.pw_shell else {
      return nil
    }
    return String(cString: shell)
  }

  private static func normalizedShellPath(_ path: String?) -> String? {
    guard let path = path?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty else {
      return nil
    }
    return path
  }

  private static func executableShellPath(_ path: String?) -> String? {
    guard let path = normalizedShellPath(path), path.hasPrefix("/") else {
      return nil
    }
    var isDirectory = ObjCBool(false)
    guard
      FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
      !isDirectory.boolValue,
      FileManager.default.isExecutableFile(atPath: path)
    else {
      return nil
    }
    return path
  }
}
