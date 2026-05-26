import ComposableArchitecture
import Foundation
import Testing

@testable import SupatermCLIShared
@testable import supaterm

@MainActor
struct TerminalAgentSessionStoreTests {
  @Test
  func recordsSessionSurfaceID() {
    let store = TerminalAgentSessionStore(
      agentRunningTimeout: .seconds(15),
      transcriptPollInterval: .seconds(1),
      sleep: { _ in }
    )
    let surfaceID = UUID()
    let context = SupatermCLIContext(surfaceID: surfaceID, tabID: UUID())

    store.beginSession(
      agent: .claude,
      sessionID: "session-1",
      context: context,
      transcriptPath: nil
    )

    #expect(store.sessionSurfaceID(agent: .claude, sessionID: "session-1") == surfaceID)
  }

  @Test
  func runningTimeoutNotifiesDelegate() async {
    let clock = TestClock()
    let delegate = SessionStoreDelegateSpy()
    let store = TerminalAgentSessionStore(
      agentRunningTimeout: .seconds(5),
      transcriptPollInterval: .seconds(1),
      sleep: { duration in
        try await clock.sleep(for: duration)
      }
    )
    store.delegate = delegate

    store.armRunningTimeout(agent: .codex, sessionID: "session-1", context: nil)

    await flushEffects()
    await clock.advance(by: .seconds(5))
    await flushEffects()

    #expect(delegate.expirations.count == 1)
    #expect(delegate.expirations.first?.0 == .codex)
    #expect(delegate.expirations.first?.1 == "session-1")
  }

  @Test
  func clearSessionCancelsPendingTimeout() async {
    let clock = TestClock()
    let delegate = SessionStoreDelegateSpy()
    let store = TerminalAgentSessionStore(
      agentRunningTimeout: .seconds(5),
      transcriptPollInterval: .seconds(1),
      sleep: { duration in
        try await clock.sleep(for: duration)
      }
    )
    store.delegate = delegate
    let surfaceID = UUID()

    store.beginSession(
      agent: .codex,
      sessionID: "session-1",
      context: SupatermCLIContext(surfaceID: surfaceID, tabID: UUID()),
      transcriptPath: nil
    )
    store.armRunningTimeout(agent: .codex, sessionID: "session-1", context: nil)
    store.clearSession(agent: .codex, sessionID: "session-1")

    await flushEffects()
    await clock.advance(by: .seconds(5))
    await flushEffects()

    #expect(delegate.expirations.isEmpty)
  }

  @Test
  func beginCodexTrackingPublishesActiveTranscriptSnapshot() throws {
    let delegate = SessionStoreDelegateSpy()
    let store = TerminalAgentSessionStore(
      agentRunningTimeout: .seconds(5),
      transcriptPollInterval: .seconds(1),
      sleep: { _ in }
    )
    store.delegate = delegate
    let transcriptURL = try CodexTranscriptFixtures.makeTranscript()
    defer { try? FileManager.default.removeItem(at: transcriptURL.deletingLastPathComponent()) }

    try CodexTranscriptFixtures.append(.taskStarted(turnID: "turn-1"), to: transcriptURL)
    let context = SupatermCLIContext(surfaceID: UUID(), tabID: UUID())
    store.beginSession(
      agent: .codex,
      sessionID: "session-1",
      context: context,
      transcriptPath: transcriptURL.path
    )

    #expect(store.beginCodexTracking(sessionID: "session-1", context: context))
    #expect(delegate.transcriptSnapshots.count == 1)
    #expect(delegate.transcriptSnapshots.first?.status == .started("turn-1"))
    #expect(delegate.transcriptSnapshots.first?.detail == nil)
  }

  @Test
  func beginCodexTrackingIgnoresStaleFinalSnapshotAndPublishesLaterTurn() async throws {
    let clock = TestClock()
    let delegate = SessionStoreDelegateSpy()
    let store = TerminalAgentSessionStore(
      agentRunningTimeout: .seconds(5),
      transcriptPollInterval: .seconds(1),
      sleep: { duration in
        try await clock.sleep(for: duration)
      }
    )
    store.delegate = delegate
    let transcriptURL = try CodexTranscriptFixtures.makeTranscript()
    defer { try? FileManager.default.removeItem(at: transcriptURL.deletingLastPathComponent()) }

    try CodexTranscriptFixtures.append(.taskComplete(turnID: "turn-0"), to: transcriptURL)
    let context = SupatermCLIContext(surfaceID: UUID(), tabID: UUID())
    store.beginSession(
      agent: .codex,
      sessionID: "session-1",
      context: context,
      transcriptPath: transcriptURL.path
    )

    #expect(store.beginCodexTracking(sessionID: "session-1", context: context))
    #expect(delegate.transcriptSnapshots.isEmpty)

    try CodexTranscriptFixtures.append(.taskStarted(turnID: "turn-1"), to: transcriptURL)

    await flushEffects()
    await clock.advance(by: .seconds(1))
    await flushEffects()

    #expect(delegate.transcriptSnapshots.count == 1)
    #expect(delegate.transcriptSnapshots.first?.status == .started("turn-1"))
    #expect(delegate.transcriptSnapshots.first?.detail == nil)
  }

  @Test
  func beginClaudePanelTrackingPublishesTaskSnapshot() throws {
    let homeDirectoryURL = try ClaudeProgressFixtures.makeHomeDirectory()
    defer { try? FileManager.default.removeItem(at: homeDirectoryURL) }
    let delegate = SessionStoreDelegateSpy()
    let store = TerminalAgentSessionStore(
      agentRunningTimeout: .seconds(5),
      transcriptPollInterval: .seconds(1),
      claudeTasksHomeDirectoryURL: homeDirectoryURL,
      sleep: { _ in }
    )
    store.delegate = delegate
    let context = SupatermCLIContext(surfaceID: UUID(), tabID: UUID())
    try ClaudeProgressFixtures.writeTask(
      id: "task-1",
      subject: "Read task files",
      status: "in_progress",
      sessionID: "session-1",
      homeDirectoryURL: homeDirectoryURL
    )
    store.beginSession(
      agent: .claude,
      sessionID: "session-1",
      context: context,
      transcriptPath: nil
    )

    #expect(store.beginAgentPanelTracking(agent: .claude, sessionID: "session-1", context: context))
    #expect(
      delegate.panelSnapshots == [
        AgentPanelSnapshot(
          progressRows: [
            PaneAgentProgressRow(
              id: "claude-task:task-1",
              title: "Read task files",
              status: .running
            )
          ]
        )
      ]
    )
  }

  @Test
  func beginClaudePanelTrackingPollsTaskChanges() async throws {
    let clock = TestClock()
    let homeDirectoryURL = try ClaudeProgressFixtures.makeHomeDirectory()
    defer { try? FileManager.default.removeItem(at: homeDirectoryURL) }
    let delegate = SessionStoreDelegateSpy()
    let store = TerminalAgentSessionStore(
      agentRunningTimeout: .seconds(5),
      transcriptPollInterval: .seconds(1),
      claudeTasksHomeDirectoryURL: homeDirectoryURL,
      sleep: { duration in
        try await clock.sleep(for: duration)
      }
    )
    store.delegate = delegate
    let context = SupatermCLIContext(surfaceID: UUID(), tabID: UUID())
    store.beginSession(
      agent: .claude,
      sessionID: "session-1",
      context: context,
      transcriptPath: nil
    )

    #expect(store.beginAgentPanelTracking(agent: .claude, sessionID: "session-1", context: context))
    #expect(delegate.panelSnapshots == [AgentPanelSnapshot()])

    try ClaudeProgressFixtures.writeTask(
      id: "task-1",
      subject: "Refresh tasks",
      status: "completed",
      sessionID: "session-1",
      homeDirectoryURL: homeDirectoryURL
    )

    await flushEffects()
    await clock.advance(by: .seconds(1))
    await flushEffects()

    #expect(
      delegate.panelSnapshots.last
        == AgentPanelSnapshot(
          progressRows: [
            PaneAgentProgressRow(
              id: "claude-task:task-1",
              title: "Refresh tasks",
              status: .completed
            )
          ]
        )
    )
  }

  @Test
  func beginClaudePanelTrackingUsesTasksBeforeTodoTranscript() throws {
    let homeDirectoryURL = try ClaudeProgressFixtures.makeHomeDirectory()
    defer { try? FileManager.default.removeItem(at: homeDirectoryURL) }
    let transcriptURL = try ClaudeProgressFixtures.makeTranscript()
    defer { try? FileManager.default.removeItem(at: transcriptURL.deletingLastPathComponent()) }
    let delegate = SessionStoreDelegateSpy()
    let store = TerminalAgentSessionStore(
      agentRunningTimeout: .seconds(5),
      transcriptPollInterval: .seconds(1),
      claudeTasksHomeDirectoryURL: homeDirectoryURL,
      sleep: { _ in }
    )
    store.delegate = delegate
    let context = SupatermCLIContext(surfaceID: UUID(), tabID: UUID())
    try ClaudeProgressFixtures.appendTodoWrite(
      [
        ["content": "Transcript row", "status": "in_progress"]
      ],
      to: transcriptURL
    )
    try ClaudeProgressFixtures.writeTask(
      id: "task-1",
      subject: "Task row",
      status: "pending",
      sessionID: "session-1",
      homeDirectoryURL: homeDirectoryURL
    )
    store.beginSession(
      agent: .claude,
      sessionID: "session-1",
      context: context,
      transcriptPath: transcriptURL.path
    )

    #expect(store.beginAgentPanelTracking(agent: .claude, sessionID: "session-1", context: context))
    #expect(
      delegate.panelSnapshots == [
        AgentPanelSnapshot(
          progressRows: [
            PaneAgentProgressRow(
              id: "claude-task:task-1",
              title: "Task row",
              status: .pending
            )
          ]
        )
      ]
    )
  }

  @Test
  func beginClaudePanelTrackingUsesTranscriptTasksWhenTaskFilesAreEmpty() throws {
    let homeDirectoryURL = try ClaudeProgressFixtures.makeHomeDirectory()
    defer { try? FileManager.default.removeItem(at: homeDirectoryURL) }
    let transcriptURL = try ClaudeProgressFixtures.makeTranscript()
    defer { try? FileManager.default.removeItem(at: transcriptURL.deletingLastPathComponent()) }
    let delegate = SessionStoreDelegateSpy()
    let store = TerminalAgentSessionStore(
      agentRunningTimeout: .seconds(5),
      transcriptPollInterval: .seconds(1),
      claudeTasksHomeDirectoryURL: homeDirectoryURL,
      sleep: { _ in }
    )
    store.delegate = delegate
    let context = SupatermCLIContext(surfaceID: UUID(), tabID: UUID())
    try ClaudeProgressFixtures.appendTaskReminder(
      [
        [
          "id": "1",
          "subject": "Transcript task row",
          "status": "in_progress",
          "blockedBy": [],
        ]
      ],
      to: transcriptURL
    )
    store.beginSession(
      agent: .claude,
      sessionID: "session-1",
      context: context,
      transcriptPath: transcriptURL.path
    )

    #expect(store.beginAgentPanelTracking(agent: .claude, sessionID: "session-1", context: context))
    #expect(
      delegate.panelSnapshots == [
        AgentPanelSnapshot(
          progressRows: [
            PaneAgentProgressRow(
              id: "claude-task:1",
              title: "Transcript task row",
              status: .running
            )
          ]
        )
      ]
    )
  }

  @Test
  func beginClaudePanelTrackingPollsTranscriptTaskChanges() async throws {
    let clock = TestClock()
    let homeDirectoryURL = try ClaudeProgressFixtures.makeHomeDirectory()
    defer { try? FileManager.default.removeItem(at: homeDirectoryURL) }
    let transcriptURL = try ClaudeProgressFixtures.makeTranscript()
    defer { try? FileManager.default.removeItem(at: transcriptURL.deletingLastPathComponent()) }
    let delegate = SessionStoreDelegateSpy()
    let store = TerminalAgentSessionStore(
      agentRunningTimeout: .seconds(5),
      transcriptPollInterval: .seconds(1),
      claudeTasksHomeDirectoryURL: homeDirectoryURL,
      sleep: { duration in
        try await clock.sleep(for: duration)
      }
    )
    store.delegate = delegate
    let context = SupatermCLIContext(surfaceID: UUID(), tabID: UUID())
    store.beginSession(
      agent: .claude,
      sessionID: "session-1",
      context: context,
      transcriptPath: transcriptURL.path
    )

    #expect(store.beginAgentPanelTracking(agent: .claude, sessionID: "session-1", context: context))
    #expect(delegate.panelSnapshots == [AgentPanelSnapshot()])

    try ClaudeProgressFixtures.appendTaskCreate(
      toolUseID: "toolu_create_1",
      subject: "Polled transcript row",
      to: transcriptURL
    )
    try ClaudeProgressFixtures.appendTaskCreateResult(
      toolUseID: "toolu_create_1",
      taskID: "1",
      subject: "Polled transcript row",
      to: transcriptURL
    )

    await flushEffects()
    await clock.advance(by: .seconds(1))
    await flushEffects()

    #expect(
      delegate.panelSnapshots.last
        == AgentPanelSnapshot(
          progressRows: [
            PaneAgentProgressRow(
              id: "claude-task:1",
              title: "Polled transcript row",
              status: .pending
            )
          ]
        )
    )
  }

  private func flushEffects() async {
    for _ in 0..<5 {
      await Task.yield()
    }
  }
}

@MainActor
private final class SessionStoreDelegateSpy: TerminalAgentSessionStoreDelegate {
  var expirations: [(SupatermAgentKind, String)] = []
  var panelSnapshots: [AgentPanelSnapshot] = []
  var transcriptSnapshots: [CodexSidebarSnapshot] = []

  func terminalAgentSessionStore(
    _ store: TerminalAgentSessionStore,
    didReceiveCodexSidebarSnapshot snapshot: CodexSidebarSnapshot,
    agent: SupatermAgentKind,
    sessionID: String,
    context: SupatermCLIContext?
  ) {
    transcriptSnapshots.append(snapshot)
  }

  func terminalAgentSessionStore(
    _ store: TerminalAgentSessionStore,
    didReceiveAgentPanelSnapshot snapshot: AgentPanelSnapshot,
    agent: SupatermAgentKind,
    sessionID: String,
    context: SupatermCLIContext?
  ) {
    panelSnapshots.append(snapshot)
  }

  func terminalAgentSessionStore(
    _ store: TerminalAgentSessionStore,
    didExpireRunningTimeoutFor agent: SupatermAgentKind,
    sessionID: String,
    context: SupatermCLIContext?
  ) {
    expirations.append((agent, sessionID))
  }
}
