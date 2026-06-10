import Foundation

struct ClaudeProgressCursor {
  var transcriptOffset: UInt64
  fileprivate var transcriptState = ClaudeTranscriptTaskState()

  init(transcriptOffset: UInt64) {
    self.transcriptOffset = transcriptOffset
  }

  fileprivate init(
    transcriptOffset: UInt64,
    transcriptState: ClaudeTranscriptTaskState
  ) {
    self.transcriptOffset = transcriptOffset
    self.transcriptState = transcriptState
  }
}

private struct ClaudeProgressTask: Equatable {
  var taskID: String
  var title: String
  var status: PaneAgentProgressRow.Status
  var blockedBy: [String]
  var modificationDate: Date?
  var metadata: AgentTranscriptJSONObject

  var isInternal: Bool {
    metadata["_internal"] == .bool(true)
  }

  var row: PaneAgentProgressRow {
    PaneAgentProgressRow(
      id: "claude-task:\(taskID)",
      title: title,
      status: status
    )
  }

  func precedes(_ other: Self) -> Bool {
    if let lhs = Int(taskID), let rhs = Int(other.taskID) {
      return lhs < rhs
    }
    return taskID.localizedStandardCompare(other.taskID) == .orderedAscending
  }
}

private enum ClaudeProgressTaskOrdering {
  static let recentCompletedInterval: TimeInterval = 30

  static func rows(
    _ tasks: [ClaudeProgressTask],
    now: Date = Date()
  ) -> [PaneAgentProgressRow] {
    let visibleTasks = tasks.filter { !$0.isInternal }
    let unresolvedIDs = Set(visibleTasks.filter { $0.status != .completed }.map(\.taskID))
    return visibleTasks.sorted { lhs, rhs in
      let lhsBucket = displayBucket(lhs, now: now)
      let rhsBucket = displayBucket(rhs, now: now)
      if lhsBucket != rhsBucket {
        return lhsBucket < rhsBucket
      }
      if lhsBucket == 2 {
        let lhsBlocked = lhs.blockedBy.contains { unresolvedIDs.contains($0) }
        let rhsBlocked = rhs.blockedBy.contains { unresolvedIDs.contains($0) }
        if lhsBlocked != rhsBlocked {
          return !lhsBlocked
        }
      }
      return lhs.precedes(rhs)
    }.map(\.row)
  }

  private static func displayBucket(
    _ task: ClaudeProgressTask,
    now: Date
  ) -> Int {
    switch task.status {
    case .completed:
      if let modificationDate = task.modificationDate,
        now.timeIntervalSince(modificationDate) < recentCompletedInterval
      {
        return 0
      }
      return 3
    case .running:
      return 1
    case .pending:
      return 2
    }
  }
}

enum ClaudeTaskProgressReader {
  static func progressRows(
    sessionID: String,
    homeDirectoryURL: URL,
    now: Date = Date()
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
    let rows =
      taskURLs
      .filter { $0.pathExtension == "json" }
      .compactMap(progressTask)

    return ClaudeProgressTaskOrdering.rows(rows, now: now)
  }

  static func sanitizedTaskListID(_ value: String) -> String {
    let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
    return String(
      value.unicodeScalars.map { scalar in
        allowed.contains(scalar) ? Character(scalar) : "-"
      }
    )
  }

  private static func progressTask(
    at url: URL
  ) -> ClaudeProgressTask? {
    guard
      let data = try? Data(contentsOf: url),
      let rawObject = try? JSONSerialization.jsonObject(with: data),
      let object = AgentTranscriptJSONValue(rawObject)?.objectValue,
      object["metadata"]?.objectValue?["_internal"] != .bool(true),
      let id = object["id"]?.stringValue,
      let title = AgentProgressParsing.normalizedTitle(object["subject"]?.stringValue)
    else {
      return nil
    }
    return ClaudeProgressTask(
      taskID: id,
      title: title,
      status: AgentProgressParsing.status(object["status"]?.stringValue),
      blockedBy: object["blockedBy"]?.arrayValue?.compactMap(\.stringValue) ?? [],
      modificationDate: (try? url.resourceValues(forKeys: [.contentModificationDateKey]))
        .flatMap(\.contentModificationDate),
      metadata: object["metadata"]?.objectValue ?? [:]
    )
  }
}

private struct ClaudePendingTask: Equatable {
  var title: String
  var blockedBy: [String]
  var metadata: AgentTranscriptJSONObject
}

private struct ClaudeTranscriptTaskState: Equatable {
  var tasks: [String: ClaudeProgressTask] = [:]
  var pendingCreates: [String: ClaudePendingTask] = [:]

  mutating func apply(_ object: AgentTranscriptJSONObject) -> [PaneAgentProgressRow]? {
    let timestamp = Self.timestamp(in: object) ?? Date()
    if let rows = applyTaskReminder(object, timestamp: timestamp) {
      return rows
    }
    switch object["type"]?.stringValue {
    case "assistant":
      return applyAssistantLine(object, timestamp: timestamp)
    case "user":
      return applyUserLine(object, timestamp: timestamp)
    default:
      return nil
    }
  }

  private mutating func applyTaskReminder(
    _ object: AgentTranscriptJSONObject,
    timestamp: Date
  ) -> [PaneAgentProgressRow]? {
    guard
      object["type"]?.stringValue == "attachment",
      let attachment = object["attachment"]?.objectValue,
      attachment["type"]?.stringValue == "task_reminder",
      let content = attachment["content"]?.arrayValue
    else {
      return nil
    }
    tasks.removeAll()
    for value in content {
      guard var task = Self.task(from: value.objectValue, timestamp: timestamp) else {
        continue
      }
      task.modificationDate = timestamp
      tasks[task.taskID] = task
    }
    pendingCreates.removeAll()
    return taskRows()
  }

  private mutating func applyAssistantLine(
    _ object: AgentTranscriptJSONObject,
    timestamp: Date
  ) -> [PaneAgentProgressRow]? {
    guard let content = object["message"]?.objectValue?["content"]?.arrayValue else { return nil }
    var didChangeTasks = false
    var latestTodoRows: [PaneAgentProgressRow]?
    for item in content {
      guard let toolUse = item.objectValue,
        toolUse["type"]?.stringValue == "tool_use"
      else {
        continue
      }
      switch toolUse["name"]?.stringValue {
      case "TaskCreate":
        didChangeTasks = applyTaskCreate(toolUse, timestamp: timestamp) || didChangeTasks
      case "TaskUpdate":
        didChangeTasks = applyTaskUpdate(toolUse, timestamp: timestamp) || didChangeTasks
      case "TodoWrite":
        latestTodoRows = Self.todoWriteRows(in: toolUse)
      default:
        continue
      }
    }
    if let latestTodoRows {
      if taskRows().isEmpty {
        return latestTodoRows
      }
    }
    guard didChangeTasks else { return nil }
    return taskRows()
  }

  private mutating func applyUserLine(
    _ object: AgentTranscriptJSONObject,
    timestamp: Date
  ) -> [PaneAgentProgressRow]? {
    guard
      let content = object["message"]?.objectValue?["content"]?.arrayValue,
      let resultObject = object["toolUseResult"]?.objectValue?["task"]?.objectValue,
      let taskID = resultObject["id"]?.stringValue
    else {
      return nil
    }
    var didChangeTasks = false
    for item in content {
      guard
        let result = item.objectValue,
        result["type"]?.stringValue == "tool_result",
        let toolUseID = result["tool_use_id"]?.stringValue
      else {
        continue
      }
      let pending = pendingCreates.removeValue(forKey: toolUseID)
      let title = AgentProgressParsing.normalizedTitle(
        pending?.title ?? resultObject["subject"]?.stringValue
      )
      guard let title else { continue }
      tasks[taskID] = ClaudeProgressTask(
        taskID: taskID,
        title: title,
        status: .pending,
        blockedBy: pending?.blockedBy ?? [],
        modificationDate: timestamp,
        metadata: pending?.metadata ?? [:]
      )
      didChangeTasks = true
    }
    guard didChangeTasks else { return nil }
    return taskRows()
  }

  private mutating func applyTaskCreate(
    _ toolUse: AgentTranscriptJSONObject,
    timestamp: Date
  ) -> Bool {
    guard
      let input = toolUse["input"]?.objectValue,
      let title = AgentProgressParsing.normalizedTitle(input["subject"]?.stringValue)
    else {
      return false
    }
    let blockedBy = input["blockedBy"]?.arrayValue?.compactMap(\.stringValue) ?? []
    let metadata = input["metadata"]?.objectValue ?? [:]
    if let taskID = input["id"]?.stringValue {
      tasks[taskID] = ClaudeProgressTask(
        taskID: taskID,
        title: title,
        status: .pending,
        blockedBy: blockedBy,
        modificationDate: timestamp,
        metadata: metadata
      )
      return true
    }
    guard let toolUseID = toolUse["id"]?.stringValue else { return false }
    pendingCreates[toolUseID] = ClaudePendingTask(
      title: title,
      blockedBy: blockedBy,
      metadata: metadata
    )
    return false
  }

  private mutating func applyTaskUpdate(
    _ toolUse: AgentTranscriptJSONObject,
    timestamp: Date
  ) -> Bool {
    guard
      let input = toolUse["input"]?.objectValue,
      let taskID = input["taskId"]?.stringValue
    else {
      return false
    }
    if input["status"]?.stringValue == "deleted" {
      return tasks.removeValue(forKey: taskID) != nil
    }
    guard var task = tasks[taskID] else {
      guard let title = AgentProgressParsing.normalizedTitle(input["subject"]?.stringValue) else {
        return false
      }
      tasks[taskID] = ClaudeProgressTask(
        taskID: taskID,
        title: title,
        status: AgentProgressParsing.status(input["status"]?.stringValue),
        blockedBy: input["addBlockedBy"]?.arrayValue?.compactMap(\.stringValue) ?? [],
        modificationDate: timestamp,
        metadata: input["metadata"]?.objectValue ?? [:]
      )
      return true
    }
    if let title = AgentProgressParsing.normalizedTitle(input["subject"]?.stringValue) {
      task.title = title
    }
    if input["status"]?.stringValue != nil {
      task.status = AgentProgressParsing.status(input["status"]?.stringValue)
    }
    if let blockedBy = input["addBlockedBy"]?.arrayValue?.compactMap(\.stringValue),
      !blockedBy.isEmpty
    {
      task.blockedBy.append(contentsOf: blockedBy.filter { !task.blockedBy.contains($0) })
    }
    if let metadata = input["metadata"]?.objectValue {
      for (key, value) in metadata {
        if value == .null {
          task.metadata.removeValue(forKey: key)
        } else {
          task.metadata[key] = value
        }
      }
    }
    task.modificationDate = timestamp
    tasks[taskID] = task
    return true
  }

  private func taskRows() -> [PaneAgentProgressRow] {
    ClaudeProgressTaskOrdering.rows(Array(tasks.values))
  }

  private static func task(
    from object: AgentTranscriptJSONObject?,
    timestamp: Date
  ) -> ClaudeProgressTask? {
    guard
      let object,
      let id = object["id"]?.stringValue,
      let title = AgentProgressParsing.normalizedTitle(object["subject"]?.stringValue)
    else {
      return nil
    }
    return ClaudeProgressTask(
      taskID: id,
      title: title,
      status: AgentProgressParsing.status(object["status"]?.stringValue),
      blockedBy: object["blockedBy"]?.arrayValue?.compactMap(\.stringValue) ?? [],
      modificationDate: timestamp,
      metadata: object["metadata"]?.objectValue ?? [:]
    )
  }

  private static func todoWriteRows(
    in object: AgentTranscriptJSONObject
  ) -> [PaneAgentProgressRow]? {
    guard
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

  private static func timestamp(in object: AgentTranscriptJSONObject) -> Date? {
    guard let value = object["timestamp"]?.stringValue else { return nil }
    return fractionalTimestampFormatter.date(from: value)
      ?? timestampFormatter.date(from: value)
  }

  private static let fractionalTimestampFormatter: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let timestampFormatter = ISO8601DateFormatter()
}

enum ClaudeTranscriptProgressMonitor {
  static func start(
    at path: String
  ) -> (cursor: ClaudeProgressCursor, rows: [PaneAgentProgressRow]?) {
    guard let data = read(path: path, from: 0) else {
      return (ClaudeProgressCursor(transcriptOffset: 0), nil)
    }
    var state = ClaudeTranscriptTaskState()
    let (consumedBytes, rows) = parse(data, state: &state)
    return (
      ClaudeProgressCursor(transcriptOffset: UInt64(consumedBytes), transcriptState: state),
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
    var state = cursor.transcriptState
    let (consumedBytes, rows) = parse(data, state: &state)
    var updatedCursor = cursor
    updatedCursor.transcriptOffset += UInt64(consumedBytes)
    updatedCursor.transcriptState = state
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

  private static func parse(
    _ data: Data,
    state: inout ClaudeTranscriptTaskState
  ) -> (Int, [PaneAgentProgressRow]?) {
    guard let newlineIndex = data.lastIndex(of: 0x0A) else {
      return (0, nil)
    }
    let completeData = data.prefix(through: newlineIndex)
    var latestRows: [PaneAgentProgressRow]?
    for line in completeData.split(separator: 0x0A) {
      guard
        let rawObject = try? JSONSerialization.jsonObject(with: Data(line)),
        let object = AgentTranscriptJSONValue(rawObject)?.objectValue
      else {
        continue
      }
      if let rows = state.apply(object) {
        latestRows = rows
      }
    }
    return (completeData.count, latestRows)
  }
}
