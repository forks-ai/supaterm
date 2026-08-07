import Foundation
import SupatermCLIShared

nonisolated enum ClaudeSubagentTranscriptReader {
  struct Reading: Equatable {
    let spawnPrompt: String?
    let usage: TerminalAgentChildUsage?
  }

  static func spawnPrompt(at url: URL) -> String? {
    guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
    defer { try? handle.close() }
    return firstObject(handle).flatMap(promptText(in:))
  }

  static func read(at url: URL) -> Reading? {
    guard let handle = try? FileHandle(forReadingFrom: url),
      let size = try? handle.seekToEnd(),
      size > 0
    else {
      return nil
    }
    defer { try? handle.close() }
    guard let spawn = firstObject(handle) else { return nil }
    let spawnPrompt = promptText(in: spawn)
    let timestamps = ISO8601DateFormatter()
    timestamps.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    guard let startedAt = timestamps.date(from: spawn["timestamp"]?.stringValue ?? "") else {
      return Reading(spawnPrompt: spawnPrompt, usage: nil)
    }
    var model: String?
    var contextTokens = 0
    var lastActiveAt = startedAt
    for line in lastLines(handle, size: size).reversed().prefix(maxScannedLines) {
      guard let object = (try? JSONDecoder().decode(JSONValue.self, from: line))?.objectValue
      else { continue }
      if let timestamp = timestamps.date(from: object["timestamp"]?.stringValue ?? "") {
        lastActiveAt = max(lastActiveAt, timestamp)
      }
      guard object["type"]?.stringValue == "assistant",
        let message = object["message"]?.objectValue,
        let usage = message["usage"]?.objectValue
      else {
        continue
      }
      model = message["model"]?.stringValue
      contextTokens = [
        "input_tokens", "cache_creation_input_tokens", "cache_read_input_tokens",
      ]
      .compactMap { usage[$0]?.intValue }
      .reduce(0, +)
      break
    }
    return Reading(
      spawnPrompt: spawnPrompt,
      usage: TerminalAgentChildUsage(
        model: model,
        contextTokens: contextTokens,
        startedAt: startedAt,
        lastActiveAt: lastActiveAt
      )
    )
  }

  private static let maxLineBytes = 262_144
  private static let lineChunkBytes = 16_384
  private static let maxTailBytes: UInt64 = 262_144
  private static let maxScannedLines = 64
  private static let newline = UInt8(0x0A)

  private static func firstObject(_ handle: FileHandle) -> JSONObject? {
    try? handle.seek(toOffset: 0)
    var line = Data()
    while line.count < maxLineBytes {
      guard let chunk = try? handle.read(upToCount: lineChunkBytes), !chunk.isEmpty else { break }
      guard let end = chunk.firstIndex(of: newline) else {
        line.append(chunk)
        continue
      }
      line.append(chunk[..<end])
      break
    }
    return (try? JSONDecoder().decode(JSONValue.self, from: line))?.objectValue
  }

  private static func lastLines(_ handle: FileHandle, size: UInt64) -> [Data] {
    let offset = size > maxTailBytes ? size - maxTailBytes : 0
    try? handle.seek(toOffset: offset)
    guard let data = try? handle.readToEnd() else { return [] }
    let lines: [Data.SubSequence] = data.split(omittingEmptySubsequences: true) {
      $0 == newline
    }
    return (offset == 0 ? lines[...] : lines.dropFirst()).map { Data($0) }
  }

  private static func promptText(in object: JSONObject) -> String? {
    let content = object["message"]?.objectValue?["content"]
    if let text = content?.stringValue {
      return text
    }
    return content?.arrayValue?
      .compactMap { $0.objectValue?["text"]?.stringValue }
      .first
  }
}
