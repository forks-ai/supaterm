import XCTest

final class AgentSessionLifecycleUITests: SupatermUITestCase {
  @MainActor
  func testClaudeLifecycleUpdatesSidebarAndPanel() async throws {
    let tabRows = sidebarTabRows
    let firstTab = await requireFirstTab()

    try await sendClaudeEvent("session-start")
    try await sendClaudeEvent("user-prompt-submit")

    await assertEventually(firstTab, timeout: AgentUITest.coldStartTimeout) {
      $0.label.contains("Agent activity: Running")
    }
    try await assertAgentPanelMenuItem(isEnabled: true)

    try await sendClaudeEvent("notification")
    try clickMenuItem(.newTab, timeout: 60)

    let secondTab = tabRows.element(boundBy: 1)
    await assertEventually(secondTab, timeout: AgentUITest.coldStartTimeout) {
      $0.exists && $0.isHittable && $0.isSelected
    }
    await selectTab(firstTab)
    await selectTab(secondTab)
    await assertEventually(firstTab, timeout: AgentUITest.coldStartTimeout) {
      $0.label.contains("Agent activity: Needs input")
    }

    await selectTab(firstTab)
    try await sendClaudeEvent("stop")

    await assertEventually(firstTab, timeout: AgentUITest.coldStartTimeout) {
      $0.label.contains("Done.") && !$0.label.contains("Agent activity:")
    }
    try await sendClaudeEvent("session-end")
    try await assertAgentPanelMenuItem(isEnabled: false)
  }

  @MainActor
  func testSessionStartKeepsAgentIdleUntilPromptSubmit() async throws {
    let firstTab = await requireFirstTab()

    try await sendClaudeEvent("session-start")
    try await assertAgentPanelMenuItem(isEnabled: true)
    XCTAssertFalse(firstTab.label.contains("Agent activity:"))

    try await sendClaudeEvent("user-prompt-submit")
    await assertEventually(firstTab, timeout: AgentUITest.coldStartTimeout) {
      $0.label.contains("Agent activity: Running")
    }

    try await sendClaudeEvent("stop")
    try await sendClaudeEvent("session-end")
    try await assertAgentPanelMenuItem(isEnabled: false)
  }
}
