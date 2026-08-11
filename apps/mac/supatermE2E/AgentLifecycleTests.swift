import Foundation
import SupatermCLIShared
import Testing

extension SupatermE2ESuite {
  @Suite struct AgentLifecycleTests {
    @Test(.timeLimit(.minutes(5)))
    func sessionStartStaysIdleUntilPromptSubmitAndEnds() async throws {
      try await withTestSpace { app, space in
        let runner = agentRunner(app, space: space)
        let sessionID = "lifecycle-\(space.token)"

        try sendClaudeEvent("session-start", sessionID: sessionID, app: app, space: space, runner: runner)
        try await expectAgent(app, paneID: space.tab.paneID, sessionID: sessionID, phase: .idle)

        try sendClaudeEvent(
          "user-prompt-submit",
          sessionID: sessionID,
          app: app,
          space: space,
          runner: runner
        )
        try await expectAgent(app, paneID: space.tab.paneID, sessionID: sessionID, phase: .running)

        try sendClaudeEvent("pre-tool-use", sessionID: sessionID, app: app, space: space, runner: runner)
        try await expectAgent(app, paneID: space.tab.paneID, sessionID: sessionID, phase: .running)

        try sendClaudeEvent("notification", sessionID: sessionID, app: app, space: space, runner: runner)
        try await expectAgent(
          app,
          paneID: space.tab.paneID,
          sessionID: sessionID,
          phase: .needsInput
        )

        try sendClaudeEvent("stop", sessionID: sessionID, app: app, space: space, runner: runner)
        try await expectAgent(app, paneID: space.tab.paneID, sessionID: sessionID, phase: .idle)
        try await app.waitUntil("the completed agent message reaches the tab") {
          try app.debugTab(space.tab.tabID)?.latestNotificationText == "Done."
        }

        try sendClaudeEvent("session-end", sessionID: sessionID, app: app, space: space, runner: runner)
        try await expectNoAgent(app, paneID: space.tab.paneID)
      }
    }

    @Test(.timeLimit(.minutes(5)))
    func newSessionInSamePaneReplacesForegroundSession() async throws {
      try await withTestSpace { app, space in
        let runner = agentRunner(app, space: space)
        let parentID = "parent-\(space.token)"
        let childID = "child-\(space.token)"

        try sendClaudeEvent("session-start", sessionID: parentID, app: app, space: space, runner: runner)
        try sendClaudeEvent(
          "user-prompt-submit",
          sessionID: parentID,
          app: app,
          space: space,
          runner: runner
        )
        try await expectAgent(app, paneID: space.tab.paneID, sessionID: parentID, phase: .running)

        try sendClaudeEvent("session-start", sessionID: childID, app: app, space: space, runner: runner)
        try await expectAgent(app, paneID: space.tab.paneID, sessionID: childID, phase: .idle)

        try sendClaudeEvent(
          "user-prompt-submit",
          sessionID: childID,
          app: app,
          space: space,
          runner: runner
        )
        try await expectAgent(app, paneID: space.tab.paneID, sessionID: childID, phase: .running)

        try sendClaudeEvent("stop", sessionID: childID, app: app, space: space, runner: runner)
        try await expectAgent(app, paneID: space.tab.paneID, sessionID: childID, phase: .idle)

        try sendClaudeEvent("session-end", sessionID: childID, app: app, space: space, runner: runner)
        try sendClaudeEvent("session-end", sessionID: parentID, app: app, space: space, runner: runner)
        try await expectNoAgent(app, paneID: space.tab.paneID)
      }
    }

    @Test(.timeLimit(.minutes(5)))
    func promptSubmitRecoversForkedSessionWithoutSessionStart() async throws {
      try await withTestSpace { app, space in
        let runner = agentRunner(app, space: space)
        let parentID = "parent-\(space.token)"
        let forkID = "fork-\(space.token)"

        try sendClaudeEvent("session-start", sessionID: parentID, app: app, space: space, runner: runner)
        try sendClaudeEvent(
          "user-prompt-submit",
          sessionID: forkID,
          app: app,
          space: space,
          runner: runner
        )
        try await expectAgent(app, paneID: space.tab.paneID, sessionID: forkID, phase: .running)

        try sendClaudeEvent("stop", sessionID: forkID, app: app, space: space, runner: runner)
        try await expectAgent(app, paneID: space.tab.paneID, sessionID: forkID, phase: .idle)
      }
    }
  }
}

private func agentRunner(_ app: SupatermE2EApp, space: TestSpace) -> SPBinaryRunner {
  SPBinaryRunner(
    executable: app.spExecutable,
    environment: app.cliEnvironment(
      context: app.context(tabID: space.tab.tabID, paneID: space.tab.paneID)
    )
  )
}

private func sendClaudeEvent(
  _ event: String,
  sessionID: String,
  app: SupatermE2EApp,
  space: TestSpace,
  runner: SPBinaryRunner
) throws {
  let result = try requireSuccessfulSPResult(
    try runner.run(
      [
        "internal", "dev", "claude", event, "--socket", app.socketPath,
        "--session-id", sessionID,
      ],
      cwd: space.directory
    )
  )
  #expect(result.stdout.contains("sent \(event) for session \(sessionID)"))
}

private func expectAgent(
  _ app: SupatermE2EApp,
  paneID: UUID,
  sessionID: String,
  phase: SupatermAppDebugSnapshot.AgentPhase
) async throws {
  try await app.waitUntil("agent session \(sessionID) reaches \(phase.rawValue)") {
    guard let agent = try app.debugPane(paneID)?.agent else { return false }
    return agent.kind == .claude && agent.sessionID == sessionID && agent.phase == phase
  }
}

private func expectNoAgent(_ app: SupatermE2EApp, paneID: UUID) async throws {
  try await app.waitUntil("the pane clears its agent session") {
    try app.debugPane(paneID)?.agent == nil
  }
}
