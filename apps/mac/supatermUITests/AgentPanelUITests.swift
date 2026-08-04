import XCTest

final class AgentPanelUITests: SupatermUITestCase {
  @MainActor
  func testCommandIAndMenuItemToggleAgentPanel() async throws {
    _ = mainWindow
    try await sendClaudeEvent("session-start")
    try await assertAgentPanelMenuItem(isEnabled: true)

    let panel = agentPanel
    await assertEventually(panel, timeout: AgentUITest.coldStartTimeout) { $0.exists }

    app.typeKey("i", modifierFlags: .command)
    await assertEventually(panel, timeout: AgentUITest.coldStartTimeout) { !$0.exists }

    app.typeKey("i", modifierFlags: .command)
    await assertEventually(panel, timeout: AgentUITest.coldStartTimeout) { $0.exists }

    try clickMenuItem(.toggleAgentPanel)
    await assertEventually(panel, timeout: AgentUITest.coldStartTimeout) { !$0.exists }
  }

  @MainActor
  func testCopySessionIDShowsTemporaryCopiedFeedback() async throws {
    _ = mainWindow
    try await sendClaudeEvent("session-start")
    try await sendClaudeEvent("user-prompt-submit")

    let copyButton = agentPanel.buttons.matching(
      NSPredicate(format: "label IN %@", ["Copy session ID", "Copied"])
    ).firstMatch
    await assertEventually(copyButton, timeout: AgentUITest.coldStartTimeout) {
      $0.exists
    }

    copyButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()

    await assertEventually(copyButton) { $0.label == "Copied" }
    await assertEventually(copyButton) { $0.label == "Copy session ID" }
  }
}
