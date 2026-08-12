import Foundation

public enum SupatermTerminalStartup: Equatable, Sendable, Codable {
  case exec([String], searchPath: String)
  case shell(String)

  private static let maximumArgumentCount = 4_096
  private static let maximumStartupBytes = 8 * 1_024 * 1_024

  public var isValid: Bool {
    switch self {
    case .exec(let arguments, let searchPath):
      Self.isValidExec(arguments, searchPath: searchPath)
    case .shell(let command):
      !command.isEmpty
        && command.utf8.count <= Self.maximumStartupBytes
        && !command.unicodeScalars.contains(where: { $0.value == 0 })
    }
  }

  private static func isValidExec(_ arguments: [String], searchPath: String) -> Bool {
    guard
      arguments.count <= maximumArgumentCount,
      let command = arguments.first,
      !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
      !searchPath.unicodeScalars.contains(where: { $0.value == 0 })
    else {
      return false
    }

    var remainingBytes = maximumStartupBytes
    for argument in arguments {
      let byteCount = argument.utf8.count
      guard
        !argument.unicodeScalars.contains(where: { $0.value == 0 }),
        byteCount < remainingBytes
      else { return false }
      remainingBytes -= byteCount + 1
    }
    return searchPath.utf8.count < remainingBytes
  }

  private enum CodingKeys: String, CodingKey {
    case kind
    case value
    case searchPath
  }

  private enum Kind: String, Codable {
    case exec
    case shell
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .exec:
      self = .exec(
        try container.decode([String].self, forKey: .value),
        searchPath: try container.decode(String.self, forKey: .searchPath)
      )
    case .shell:
      self = .shell(try container.decode(String.self, forKey: .value))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .exec(let arguments, let searchPath):
      try container.encode(Kind.exec, forKey: .kind)
      try container.encode(arguments, forKey: .value)
      try container.encode(searchPath, forKey: .searchPath)
    case .shell(let command):
      try container.encode(Kind.shell, forKey: .kind)
      try container.encode(command, forKey: .value)
    }
  }
}
