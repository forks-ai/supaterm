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

  public static func commandLine(forArguments arguments: [String], cliPath: String?) -> String? {
    guard
      let executable = arguments.first,
      URL(fileURLWithPath: executable).lastPathComponent == program,
      let session = sessionArguments(Array(arguments.dropFirst()))
    else {
      return nil
    }

    let tokens = cliPath.map { [$0, program, "--"] } ?? [program]
    return (tokens + session)
      .map(SupatermShellCommand.escapedToken)
      .joined(separator: " ")
  }

  static func sessionArguments(_ arguments: [String]) -> [String]? {
    let forwarded = Set(forwardedEnvironmentVariables.map { "SendEnv=\($0)" })
    var options: [String] = []
    var destination: String?
    var index = 0

    while index < arguments.count {
      let token = arguments[index]

      guard token.hasPrefix("-"), token.count > 1 else {
        guard destination == nil else { return nil }
        destination = token
        index += 1
        continue
      }

      guard let expectsSeparateValue = valuePlacement(in: token) else { return nil }
      guard !expectsSeparateValue || index + 1 < arguments.count else { return nil }
      let value = expectsSeparateValue ? arguments[index + 1] : nil

      index += expectsSeparateValue ? 2 : 1
      if token == "-o", let value, forwarded.contains(value) { continue }

      options.append(token)
      if let value { options.append(value) }
    }

    guard let destination else { return nil }
    return options + [destination]
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
