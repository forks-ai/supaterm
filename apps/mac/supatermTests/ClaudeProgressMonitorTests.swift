import Foundation
import Testing

@testable import supaterm

struct ClaudeProgressMonitorTests {
  @Test
  func taskFilesProduceProgressRows() throws {
    let homeDirectoryURL = try ClaudeProgressFixtures.makeHomeDirectory()
    defer { try? FileManager.default.removeItem(at: homeDirectoryURL) }

    try ClaudeProgressFixtures.writeTask(
      id: "task-2",
      subject: "Wire panel rows",
      status: "in_progress",
      sessionID: "session:123",
      homeDirectoryURL: homeDirectoryURL,
      filename: "2.json"
    )
    try ClaudeProgressFixtures.writeTask(
      id: "task-1",
      subject: "Read tasks",
      status: "completed",
      sessionID: "session:123",
      homeDirectoryURL: homeDirectoryURL,
      filename: "1.json"
    )
    try ClaudeProgressFixtures.writeTask(
      id: "task-internal",
      subject: "Internal task",
      status: "pending",
      sessionID: "session:123",
      homeDirectoryURL: homeDirectoryURL,
      filename: "3.json",
      metadata: ["_internal": true]
    )

    #expect(
      ClaudeTaskProgressReader.progressRows(
        sessionID: "session:123",
        homeDirectoryURL: homeDirectoryURL
      ) == [
        PaneAgentProgressRow(
          id: "claude-task:task-1",
          title: "Read tasks",
          status: .completed
        ),
        PaneAgentProgressRow(
          id: "claude-task:task-2",
          title: "Wire panel rows",
          status: .running
        ),
      ]
    )
  }

  @Test
  func todoWriteTranscriptProducesProgressRows() throws {
    let transcriptURL = try ClaudeProgressFixtures.makeTranscript()
    defer { try? FileManager.default.removeItem(at: transcriptURL.deletingLastPathComponent()) }

    try ClaudeProgressFixtures.appendTodoWrite(
      [
        ["content": "Read transcript", "status": "completed"],
        ["content": "Wire rows", "status": "in_progress"],
        ["content": "Run tests", "status": "pending"],
      ],
      to: transcriptURL
    )

    let result = ClaudeTodoTranscriptMonitor.start(at: transcriptURL.path)

    #expect(
      result.1?.progressRows == [
        PaneAgentProgressRow(
          id: "claude-todo:0:Read transcript",
          title: "Read transcript",
          status: .completed
        ),
        PaneAgentProgressRow(
          id: "claude-todo:1:Wire rows",
          title: "Wire rows",
          status: .running
        ),
        PaneAgentProgressRow(
          id: "claude-todo:2:Run tests",
          title: "Run tests",
          status: .pending
        ),
      ]
    )
  }

  @Test
  func advanceConsumesOnlyCompleteTranscriptLines() throws {
    let transcriptURL = try ClaudeProgressFixtures.makeTranscript()
    defer { try? FileManager.default.removeItem(at: transcriptURL.deletingLastPathComponent()) }

    let start = ClaudeTodoTranscriptMonitor.start(at: transcriptURL.path)
    let handle = try FileHandle(forWritingTo: transcriptURL)
    defer { try? handle.close() }
    try handle.seekToEnd()
    try handle.write(contentsOf: Data(#"{"type":"assistant"}"#.utf8))

    let result = try #require(ClaudeTodoTranscriptMonitor.advance(start.0, at: transcriptURL.path))

    #expect(result.0.transcriptOffset == start.0.transcriptOffset)
    #expect(result.1 == nil)
  }
}
