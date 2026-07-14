import XCTest

final class AgentPanelUITests: SupatermUITestCase {
  private static let sessionID = "agent-panel-ui-tests"

  @MainActor
  func testCommandIAndMenuItemToggleAgentPanel() async throws {
    _ = mainWindow
    try await sendClaudeEvent("session-start")

    await assertEventually(copySessionButton, timeout: .seconds(30)) { $0.exists }
    await assertEventually(hideAgentPanelButton) { $0.exists }

    app.typeKey("i", modifierFlags: .command)
    await assertEventually(copySessionButton) { !$0.exists }
    await assertEventually(showAgentPanelButton) { $0.exists }

    app.typeKey("i", modifierFlags: .command)
    await assertEventually(copySessionButton) { $0.exists }
    await assertEventually(hideAgentPanelButton) { $0.exists }

    try clickMenuItem(.toggleAgentPanel)
    await assertEventually(copySessionButton) { !$0.exists }
    await assertEventually(showAgentPanelButton) { $0.exists }
  }

  @MainActor
  func testClaudeLifecycleUpdatesSidebarAndPanel() async throws {
    _ = mainWindow

    let tabRows = app.buttons.matching(
      identifier: SupatermUITestIdentifier.Accessibility.sidebarTabRow
    )
    let firstTab = tabRows.element(boundBy: 0)
    guard firstTab.waitForExistence(timeout: 30) else {
      XCTFail("Initial sidebar tab row did not appear")
      return
    }

    try await sendClaudeEvent("session-start")
    try await sendClaudeEvent("user-prompt-submit")

    await assertEventually(firstTab, timeout: .seconds(30)) {
      $0.label.contains("Agent activity: Running")
    }

    try await sendClaudeEvent("notification")
    try clickMenuItem(.newTab)

    let secondTab = tabRows.element(boundBy: 1)
    await assertEventually(secondTab, timeout: .seconds(30)) { $0.exists }
    await assertEventually(firstTab, timeout: .seconds(30)) {
      $0.label.contains("Agent activity: Needs input")
    }

    firstTab.click()
    await assertEventually(copySessionButton, timeout: .seconds(30)) { $0.exists }
    try await sendClaudeEvent("stop")

    await assertEventually(firstTab, timeout: .seconds(30)) {
      $0.label.contains("Done.") && !$0.label.contains("Agent activity:")
    }
    try await sendClaudeEvent("session-end")
    await assertEventually(copySessionButton, timeout: .seconds(30)) { !$0.exists }
  }

  @MainActor
  private var copySessionButton: XCUIElement {
    app.buttons["Copy session ID"]
  }

  @MainActor
  private var hideAgentPanelButton: XCUIElement {
    app.buttons["Hide agent panel"]
  }

  @MainActor
  private var showAgentPanelButton: XCUIElement {
    app.buttons["Show agent panel"]
  }

  @MainActor
  private func sendClaudeEvent(_ event: String) async throws {
    let terminal = app.textViews.firstMatch
    guard await wait(for: terminal, timeout: .seconds(30), until: { $0.exists && $0.isHittable })
    else {
      XCTFail("Terminal did not become ready")
      return
    }

    terminal.click()
    app.typeText(
      "\"$SUPATERM_CLI_PATH\" internal dev claude \(event) --session-id \(Self.sessionID)"
    )
    app.typeKey(.return, modifierFlags: [])

    let expectedOutput = "sent \(event) for session \(Self.sessionID)"
    await assertEventually(terminal, timeout: .seconds(30)) {
      ($0.value as? String)?.contains(expectedOutput) == true
    }
  }

  @MainActor
  private func assertEventually(
    _ element: XCUIElement,
    timeout: Duration = .seconds(10),
    file: StaticString = #filePath,
    line: UInt = #line,
    until condition: (XCUIElement) -> Bool
  ) async {
    let didMatch = await wait(for: element, timeout: timeout, until: condition)
    XCTAssertTrue(didMatch, file: file, line: line)
  }
}
