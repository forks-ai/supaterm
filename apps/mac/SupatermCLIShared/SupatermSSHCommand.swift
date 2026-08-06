import Foundation

public enum SupatermSSHCommand {
  public static let program = "ssh"
  public static let term = "xterm-256color"
  public static let forwardedEnvironmentVariables = [
    "COLORTERM",
    "TERM_PROGRAM",
    "TERM_PROGRAM_VERSION",
  ]

  public static var forwardedEnvironmentOptions: [String] {
    forwardedEnvironmentVariables.flatMap { ["-o", "SendEnv=\($0)"] }
  }

  public static func commandLine(forArguments arguments: [String]) -> String? {
    guard
      let executable = arguments.first,
      URL(fileURLWithPath: executable).lastPathComponent == program
    else {
      return nil
    }

    let forwarded = Set(forwardedEnvironmentVariables.map { "SendEnv=\($0)" })
    var operands: [String] = []
    var index = 1
    while index < arguments.count {
      if arguments[index] == "-o", index + 1 < arguments.count,
        forwarded.contains(arguments[index + 1])
      {
        index += 2
        continue
      }
      operands.append(arguments[index])
      index += 1
    }

    guard !operands.isEmpty else { return nil }
    return ([program] + operands)
      .map(SupatermShellCommand.escapedToken)
      .joined(separator: " ")
  }
}
