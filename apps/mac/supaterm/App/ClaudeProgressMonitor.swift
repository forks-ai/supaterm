import Foundation

struct ClaudeProgressCursor {
  var transcriptOffset: UInt64
}

enum ClaudeTaskProgressReader {
  static func progressRows(
    sessionID: String,
    homeDirectoryURL: URL
  ) -> [PaneAgentProgressRow] {
    let taskDirectoryURL =
      homeDirectoryURL
      .appendingPathComponent(".claude", isDirectory: true)
      .appendingPathComponent("tasks", isDirectory: true)
      .appendingPathComponent(sanitizedTaskListID(sessionID), isDirectory: true)
    let taskURLs =
      (try? FileManager.default.contentsOfDirectory(
        at: taskDirectoryURL,
        includingPropertiesForKeys: nil
      )) ?? []
    return
      taskURLs
      .filter { $0.pathExtension == "json" }
      .sorted { lhs, rhs in
        let lhsName = lhs.deletingPathExtension().lastPathComponent
        let rhsName = rhs.deletingPathExtension().lastPathComponent
        if let lhsNumber = Int(lhsName), let rhsNumber = Int(rhsName) {
          return lhsNumber < rhsNumber
        }
        return lhs.lastPathComponent.localizedStandardCompare(rhs.lastPathComponent) == .orderedAscending
      }
      .compactMap(progressRow)
  }

  static func sanitizedTaskListID(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
    return String(
      value.unicodeScalars.map { scalar in
        allowed.contains(scalar) ? Character(scalar) : "-"
      }
    )
  }

  private static func progressRow(
    at url: URL
  ) -> PaneAgentProgressRow? {
    guard
      let data = try? Data(contentsOf: url),
      let rawObject = try? JSONSerialization.jsonObject(with: data),
      let object = CodexTranscriptJSONValue(rawObject)?.objectValue,
      object["metadata"]?.objectValue?["_internal"] != .bool(true),
      let id = object["id"]?.stringValue,
      let title = AgentProgressParsing.normalizedTitle(object["subject"]?.stringValue)
    else {
      return nil
    }
    return PaneAgentProgressRow(
      id: "claude-task:\(id)",
      title: title,
      status: AgentProgressParsing.status(object["status"]?.stringValue)
    )
  }
}

enum ClaudeTodoTranscriptMonitor {
  static func start(
    at path: String
  ) -> (cursor: ClaudeProgressCursor, rows: [PaneAgentProgressRow]?) {
    guard let data = read(path: path, from: 0) else {
      return (ClaudeProgressCursor(transcriptOffset: 0), nil)
    }
    let (consumedBytes, rows) = parse(data)
    return (
      ClaudeProgressCursor(transcriptOffset: UInt64(consumedBytes)),
      rows
    )
  }

  static func advance(
    _ cursor: ClaudeProgressCursor,
    at path: String
  ) -> (cursor: ClaudeProgressCursor, rows: [PaneAgentProgressRow]?)? {
    let fileURL = URL(fileURLWithPath: path)
    guard
      let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
      let fileSize = values.fileSize
    else {
      return nil
    }
    if UInt64(fileSize) < cursor.transcriptOffset {
      return start(at: path)
    }
    guard let data = read(path: path, from: cursor.transcriptOffset) else { return nil }
    let (consumedBytes, rows) = parse(data)
    var updatedCursor = cursor
    updatedCursor.transcriptOffset += UInt64(consumedBytes)
    return (updatedCursor, rows)
  }

  private static func read(path: String, from offset: UInt64) -> Data? {
    do {
      let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
      defer { try? handle.close() }
      try handle.seek(toOffset: offset)
      return try handle.readToEnd() ?? Data()
    } catch {
      return nil
    }
  }

  private static func parse(_ data: Data) -> (Int, [PaneAgentProgressRow]?) {
    guard let newlineIndex = data.lastIndex(of: 0x0A) else {
      return (0, nil)
    }
    let completeData = data.prefix(through: newlineIndex)
    let rows = completeData.split(separator: 0x0A).compactMap { line in
      progressRows(in: Data(line))
    }.last
    return (completeData.count, rows)
  }

  private static func progressRows(
    in line: Data
  ) -> [PaneAgentProgressRow]? {
    guard
      let rawObject = try? JSONSerialization.jsonObject(with: line),
      let object = CodexTranscriptJSONValue(rawObject)?.objectValue,
      object["type"]?.stringValue == "assistant",
      let content = object["message"]?.objectValue?["content"]?.arrayValue
    else {
      return nil
    }
    return content.compactMap(todoWriteRows).last
  }

  private static func todoWriteRows(
    in item: CodexTranscriptJSONValue
  ) -> [PaneAgentProgressRow]? {
    guard
      let object = item.objectValue,
      object["type"]?.stringValue == "tool_use",
      object["name"]?.stringValue == "TodoWrite",
      let todos = object["input"]?.objectValue?["todos"]?.arrayValue
    else {
      return nil
    }
    let rows: [PaneAgentProgressRow] = todos.enumerated().compactMap { index, value in
      guard
        let item = value.objectValue,
        let title = AgentProgressParsing.normalizedTitle(item["content"]?.stringValue)
      else {
        return nil
      }
      return PaneAgentProgressRow(
        id: "claude-todo:\(index):\(title)",
        title: title,
        status: AgentProgressParsing.status(item["status"]?.stringValue)
      )
    }
    return rows
  }
}
