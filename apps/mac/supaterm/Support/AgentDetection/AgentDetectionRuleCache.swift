import Foundation

enum AgentDetectionRuleCacheError: Error, Equatable, LocalizedError, Sendable {
  case fileTooLarge
  case rulesTooLarge
  case invalidETag

  var errorDescription: String? {
    switch self {
    case .fileTooLarge:
      "The agent detection rule cache is too large."
    case .rulesTooLarge:
      "The cached agent detection rules are too large."
    case .invalidETag:
      "The cached agent detection ETag is invalid."
    }
  }
}

struct AgentDetectionRuleCache: Sendable {
  static let maximumETagBytes = 256
  static let maximumFileBytes =
    AgentDetectionRuleSetValidator.maximumDocumentBytes
    + maximumETagBytes
    + 4_096

  struct Entry: Codable, Equatable, Sendable {
    let rules: Data
    let etag: String
  }

  let url: URL

  func load() throws -> Entry? {
    guard FileManager.default.fileExists(atPath: url.path) else { return nil }
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    let data = try handle.read(upToCount: Self.maximumFileBytes + 1) ?? Data()
    guard data.count <= Self.maximumFileBytes else {
      throw AgentDetectionRuleCacheError.fileTooLarge
    }
    let entry = try PropertyListDecoder().decode(Entry.self, from: data)
    try Self.validate(entry)
    return entry
  }

  func save(_ entry: Entry) throws {
    try Self.validate(entry)
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    let data = try encoder.encode(entry)
    guard data.count <= Self.maximumFileBytes else {
      throw AgentDetectionRuleCacheError.fileTooLarge
    }
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try data.write(to: url, options: .atomic)
  }

  static func validateETag(_ etag: String) throws {
    let bytes = etag.utf8
    guard
      !bytes.isEmpty,
      bytes.count <= maximumETagBytes,
      bytes.allSatisfy({ 0x21...0x7E ~= $0 })
    else {
      throw AgentDetectionRuleCacheError.invalidETag
    }
  }

  private static func validate(_ entry: Entry) throws {
    guard
      !entry.rules.isEmpty,
      entry.rules.count <= AgentDetectionRuleSetValidator.maximumDocumentBytes
    else {
      throw AgentDetectionRuleCacheError.rulesTooLarge
    }
    try validateETag(entry.etag)
  }
}
