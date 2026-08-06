import Foundation

public enum SupatermSSHCommand {
  public static let program = "ssh"
  public static let term = "xterm-256color"
  public static let forwardedEnvironmentVariables = [
    "COLORTERM",
    "TERM_PROGRAM",
    "TERM_PROGRAM_VERSION",
  ]

  private static let optionsTakingValue: Set<Character> = [
    "B", "b", "c", "D", "E", "e", "F", "I", "i", "J", "L", "l", "m", "O", "o", "P", "p", "Q", "R",
    "S", "W", "w",
  ]
  private static let optionsWithoutSession: Set<Character> = ["N", "W", "f"]

  public static var forwardedEnvironmentOptions: [String] {
    forwardedEnvironmentVariables.flatMap { ["-o", "SendEnv=\($0)"] }
  }

  public static func commandLine(
    forArguments arguments: [String],
    terminalType: String?,
    cliPath: String?
  ) -> String? {
    guard let executable = arguments.first else { return nil }

    let sourceArguments = Array(arguments.dropFirst())
    let launchedBySupaterm = sourceArguments.starts(with: forwardedEnvironmentOptions)
    guard launchedBySupaterm || URL(fileURLWithPath: executable).lastPathComponent == program else {
      return nil
    }

    let inheritedArguments =
      launchedBySupaterm
      ? Array(sourceArguments.dropFirst(forwardedEnvironmentOptions.count))
      : sourceArguments
    guard let sessionArguments = sessionArguments(inheritedArguments) else { return nil }

    let terminalType =
      terminalType
      .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
      .flatMap { $0.isEmpty ? nil : $0 }
    var tokens: [String]
    if let cliPath {
      tokens = [cliPath, program]
      if let terminalType {
        tokens += ["--term", terminalType]
      }
      tokens += ["--ssh", executable, "--"] + sessionArguments
    } else {
      tokens = []
      if let terminalType {
        tokens = ["/usr/bin/env", "TERM=\(terminalType)"]
      }
      tokens += [executable] + sourceArguments
    }

    return
      tokens
      .map(SupatermShellCommand.escapedToken)
      .joined(separator: " ")
  }

  private static func sessionArguments(_ arguments: [String]) -> [String]? {
    var options: [String] = []
    var index = 0

    while index < arguments.count {
      let token = arguments[index]

      guard token.hasPrefix("-"), token.count > 1 else {
        guard index == arguments.count - 1 else { return nil }
        return options + [token]
      }

      guard let expectsSeparateValue = valuePlacement(in: token) else { return nil }
      guard !expectsSeparateValue || index + 1 < arguments.count else { return nil }
      let value = expectsSeparateValue ? arguments[index + 1] : nil

      index += expectsSeparateValue ? 2 : 1
      options.append(token)
      if let value { options.append(value) }
    }

    return nil
  }

  private static func valuePlacement(in token: String) -> Bool? {
    let flags = Array(token.dropFirst())
    for (position, flag) in flags.enumerated() {
      if optionsWithoutSession.contains(flag) { return nil }
      if optionsTakingValue.contains(flag) { return position == flags.count - 1 }
    }
    return false
  }
}
