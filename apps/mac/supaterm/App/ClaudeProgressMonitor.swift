import Foundation
import SupatermCLIShared

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
  var metadata: JSONObject

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

private struct ClaudePendingTask: Equatable {
  var title: String
  var metadata: JSONObject
}

private struct ClaudeTranscriptTaskState: Equatable {
  var tasks: [String: ClaudeProgressTask] = [:]
  var pendingCreates: [String: ClaudePendingTask] = [:]
  var goalRow: PaneAgentProgressRow?

  mutating func apply(_ object: JSONObject) -> [PaneAgentProgressRow]? {
    if let rows = applyGoalStatus(object) {
      return rows
    }
    if let rows = applyTaskReminder(object) {
      return rows
    }
    switch object["type"]?.stringValue {
    case "assistant":
      return applyAssistantLine(object)
    case "user":
      return applyUserLine(object)
    default:
      return nil
    }
  }

  private mutating func applyTaskReminder(_ object: JSONObject) -> [PaneAgentProgressRow]? {
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
      guard let task = Self.task(from: value.objectValue) else {
        continue
      }
      tasks[task.taskID] = task
    }
    pendingCreates.removeAll()
    return displayRows(taskRows())
  }

  private mutating func applyAssistantLine(_ object: JSONObject) -> [PaneAgentProgressRow]? {
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
        didChangeTasks = applyTaskCreate(toolUse) || didChangeTasks
      case "TaskUpdate":
        didChangeTasks = applyTaskUpdate(toolUse) || didChangeTasks
      case "TodoWrite":
        latestTodoRows = Self.todoWriteRows(in: toolUse)
      default:
        continue
      }
    }
    if let latestTodoRows, taskRows().isEmpty {
      return displayRows(latestTodoRows)
    }
    guard didChangeTasks else { return nil }
    return displayRows(taskRows())
  }

  private mutating func applyUserLine(_ object: JSONObject) -> [PaneAgentProgressRow]? {
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
        metadata: pending?.metadata ?? [:]
      )
      didChangeTasks = true
    }
    guard didChangeTasks else { return nil }
    return displayRows(taskRows())
  }

  private mutating func applyTaskCreate(_ toolUse: JSONObject) -> Bool {
    guard
      let input = toolUse["input"]?.objectValue,
      let title = AgentProgressParsing.normalizedTitle(input["subject"]?.stringValue)
    else {
      return false
    }
    let metadata = input["metadata"]?.objectValue ?? [:]
    if let taskID = input["id"]?.stringValue {
      tasks[taskID] = ClaudeProgressTask(
        taskID: taskID,
        title: title,
        status: .pending,
        metadata: metadata
      )
      return true
    }
    guard let toolUseID = toolUse["id"]?.stringValue else { return false }
    pendingCreates[toolUseID] = ClaudePendingTask(
      title: title,
      metadata: metadata
    )
    return false
  }

  private mutating func applyTaskUpdate(_ toolUse: JSONObject) -> Bool {
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
    if let metadata = input["metadata"]?.objectValue {
      for (key, value) in metadata {
        if value == .null {
          task.metadata.removeValue(forKey: key)
        } else {
          task.metadata[key] = value
        }
      }
    }
    tasks[taskID] = task
    return true
  }

  private func taskRows() -> [PaneAgentProgressRow] {
    tasks.values
      .filter { !$0.isInternal }
      .sorted { $0.precedes($1) }
      .map(\.row)
  }

  private func displayRows(_ rows: [PaneAgentProgressRow]) -> [PaneAgentProgressRow] {
    if let goalRow {
      return [goalRow] + rows
    }
    return rows
  }

  private mutating func applyGoalStatus(_ object: JSONObject) -> [PaneAgentProgressRow]? {
    guard
      object["type"]?.stringValue == "attachment",
      let attachment = object["attachment"]?.objectValue,
      attachment["type"]?.stringValue == "goal_status"
    else {
      return nil
    }
    goalRow = Self.goalRow(from: attachment)
    return displayRows(taskRows())
  }

  private static func goalRow(from object: JSONObject) -> PaneAgentProgressRow? {
    guard let condition = AgentProgressParsing.normalizedTitle(object["condition"]?.stringValue) else {
      return nil
    }
    return PaneAgentProgressRow(
      id: "claude-goal:\(condition)",
      title: "Goal: \(condition)",
      status: object["met"]?.boolValue == true ? .completed : .running,
      kind: .goal
    )
  }

  private static func task(from object: JSONObject?) -> ClaudeProgressTask? {
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
      metadata: object["metadata"]?.objectValue ?? [:]
    )
  }

  private static func todoWriteRows(
    in object: JSONObject
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
}

@MainActor
final class ClaudePanelMonitor: AgentPanelMonitor {
  private let transcriptPath: () -> String?
  private var cursor: ClaudeProgressCursor
  private var transcriptRows: [PaneAgentProgressRow]
  private var currentSnapshot: AgentMonitorSnapshot?

  init(transcriptPath: @escaping () -> String?) {
    self.transcriptPath = transcriptPath
    let initialProgress =
      transcriptPath().map { ClaudeTranscriptProgressMonitor.start(at: $0) }
      ?? (cursor: ClaudeProgressCursor(transcriptOffset: 0), rows: nil)
    cursor = initialProgress.cursor
    transcriptRows = initialProgress.rows ?? []
  }

  func start() -> AgentPanelMonitorTick? {
    let snapshot = AgentMonitorSnapshot(progressRows: transcriptRows)
    currentSnapshot = snapshot
    return AgentPanelMonitorTick(snapshot: snapshot, isFinal: false)
  }

  func poll() -> AgentPanelMonitorTick? {
    if let path = transcriptPath(),
      let result = ClaudeTranscriptProgressMonitor.advance(cursor, at: path)
    {
      cursor = result.cursor
      if let rows = result.rows {
        transcriptRows = rows
      }
    }
    let nextSnapshot = AgentMonitorSnapshot(progressRows: transcriptRows)
    guard nextSnapshot != currentSnapshot else { return nil }
    currentSnapshot = nextSnapshot
    return AgentPanelMonitorTick(snapshot: nextSnapshot, isFinal: false)
  }
}

enum ClaudeTranscriptProgressMonitor {
  static func start(
    at path: String
  ) -> (cursor: ClaudeProgressCursor, rows: [PaneAgentProgressRow]?) {
    guard let tick = AgentTranscriptTailer.start(at: path) else {
      return (ClaudeProgressCursor(transcriptOffset: 0), nil)
    }
    var state = ClaudeTranscriptTaskState()
    let rows = apply(tick.objects, to: &state)
    return (
      ClaudeProgressCursor(transcriptOffset: tick.cursor.offset, transcriptState: state),
      rows
    )
  }

  static func advance(
    _ cursor: ClaudeProgressCursor,
    at path: String
  ) -> (cursor: ClaudeProgressCursor, rows: [PaneAgentProgressRow]?)? {
    guard
      let tick = AgentTranscriptTailer.advance(
        AgentTranscriptTailCursor(offset: cursor.transcriptOffset),
        at: path
      )
    else {
      return nil
    }
    var state = tick.didReset ? ClaudeTranscriptTaskState() : cursor.transcriptState
    let rows = apply(tick.objects, to: &state)
    return (
      ClaudeProgressCursor(transcriptOffset: tick.cursor.offset, transcriptState: state),
      rows
    )
  }

  private static func apply(
    _ objects: [JSONObject],
    to state: inout ClaudeTranscriptTaskState
  ) -> [PaneAgentProgressRow]? {
    var latestRows: [PaneAgentProgressRow]?
    for object in objects {
      if let rows = state.apply(object) {
        latestRows = rows
      }
    }
    return latestRows
  }
}
