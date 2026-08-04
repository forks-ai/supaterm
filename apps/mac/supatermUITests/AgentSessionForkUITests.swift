import XCTest

final class AgentSessionForkUITests: SupatermUITestCase {
  @MainActor
  func testNewSessionInSamePaneReplacesForegroundAgentSession() async throws {
    let firstTab = await requireFirstTab()

    try await sendClaudeEvent("session-start", sessionID: "fork-parent-session")
    try await sendClaudeEvent("user-prompt-submit", sessionID: "fork-parent-session")
    await assertEventually(firstTab, timeout: AgentUITest.coldStartTimeout) {
      $0.label.contains("Agent activity: Running")
    }

    try await sendClaudeEvent("session-start", sessionID: "fork-child-session")
    await assertEventually(firstTab, timeout: AgentUITest.coldStartTimeout) {
      !$0.label.contains("Agent activity:")
    }

    try await sendClaudeEvent("user-prompt-submit", sessionID: "fork-child-session")
    await assertEventually(firstTab, timeout: AgentUITest.coldStartTimeout) {
      $0.label.contains("Agent activity: Running")
    }

    try await sendClaudeEvent("stop", sessionID: "fork-child-session")
    await assertEventually(firstTab, timeout: AgentUITest.coldStartTimeout) {
      $0.label.contains("Done.") && !$0.label.contains("Agent activity:")
    }

    try await sendClaudeEvent("session-end", sessionID: "fork-child-session")
    try await sendClaudeEvent("session-end", sessionID: "fork-parent-session")
    try await assertAgentPanelMenuItem(isEnabled: false)
  }

  @MainActor
  func testForkedClaudeSessionRecoversSidebarActivityWithoutSessionStart() async throws {
    let firstTab = await requireFirstTab()

    try await sendClaudeEvent("session-start", sessionID: "parent-session")
    try await sendClaudeEvent("user-prompt-submit", sessionID: "forked-session")
    await assertEventually(firstTab, timeout: AgentUITest.coldStartTimeout) {
      $0.label.contains("Agent activity: Running")
    }

    try await sendClaudeEvent("stop", sessionID: "forked-session")
    await assertEventually(firstTab, timeout: AgentUITest.coldStartTimeout) {
      $0.label.contains("Done.") && !$0.label.contains("Agent activity:")
    }
  }
}
