import XCTest

final class AgentPanelUITests: SupatermUITestCase {
  private static let coldStartTimeout: TimeInterval = 60
  private static let sessionID = "agent-panel-ui-tests"

  @MainActor
  func testCommandIAndMenuItemToggleAgentPanel() throws {
    _ = mainWindow
    try sendClaudeEvent("session-start")
    try assertAgentPanelMenuItem(isEnabled: true)

    let panel = agentPanel
    assertEventually(panel, timeout: Self.coldStartTimeout) { $0.exists }

    app.typeKey("i", modifierFlags: .command)
    assertEventually(panel, timeout: Self.coldStartTimeout) { !$0.exists }

    app.typeKey("i", modifierFlags: .command)
    assertEventually(panel, timeout: Self.coldStartTimeout) { $0.exists }

    try clickMenuItem(.toggleAgentPanel)
    assertEventually(panel, timeout: Self.coldStartTimeout) { !$0.exists }
  }

  @MainActor
  func testCopySessionIDShowsTemporaryCopiedFeedback() throws {
    _ = mainWindow
    try sendClaudeEvent("session-start")
    try sendClaudeEvent("user-prompt-submit")

    let copyButton = agentPanel.buttons.matching(
      NSPredicate(format: "label IN %@", ["Copy session ID", "Copied"])
    ).firstMatch
    assertEventually(copyButton, timeout: Self.coldStartTimeout) {
      $0.exists
    }

    copyButton.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).click()

    assertEventually(copyButton) { $0.label == "Copied" }
    assertEventually(copyButton) { $0.label == "Copy session ID" }
  }

  @MainActor
  func testClaudeLifecycleUpdatesSidebarAndPanel() throws {
    let tabRows = sidebarTabRows
    let firstTab = requireFirstTab()

    try sendClaudeEvent("session-start")
    try sendClaudeEvent("user-prompt-submit")

    assertEventually(firstTab, timeout: Self.coldStartTimeout) {
      $0.label.contains("Agent activity: Running")
    }
    try assertAgentPanelMenuItem(isEnabled: true)

    try sendClaudeEvent("notification")
    try clickMenuItem(.newTab, timeout: 60)

    let secondTab = tabRows.element(boundBy: 1)
    assertEventually(secondTab, timeout: Self.coldStartTimeout) {
      $0.exists && $0.isHittable && $0.isSelected
    }
    selectTab(firstTab)
    selectTab(secondTab)
    assertEventually(firstTab, timeout: Self.coldStartTimeout) {
      $0.label.contains("Agent activity: Needs input")
    }

    selectTab(firstTab)
    try sendClaudeEvent("stop")

    assertEventually(firstTab, timeout: Self.coldStartTimeout) {
      $0.label.contains("Done.") && !$0.label.contains("Agent activity:")
    }
    try sendClaudeEvent("session-end")
    try assertAgentPanelMenuItem(isEnabled: false)
  }

  @MainActor
  func testNewSessionInSamePaneReplacesForegroundAgentSession() throws {
    let firstTab = requireFirstTab()

    try sendClaudeEvent("session-start", sessionID: "fork-parent-session")
    try sendClaudeEvent("user-prompt-submit", sessionID: "fork-parent-session")
    assertEventually(firstTab, timeout: Self.coldStartTimeout) {
      $0.label.contains("Agent activity: Running")
    }

    try sendClaudeEvent("session-start", sessionID: "fork-child-session")
    assertEventually(firstTab, timeout: Self.coldStartTimeout) {
      !$0.label.contains("Agent activity:")
    }

    try sendClaudeEvent("user-prompt-submit", sessionID: "fork-child-session")
    assertEventually(firstTab, timeout: Self.coldStartTimeout) {
      $0.label.contains("Agent activity: Running")
    }

    try sendClaudeEvent("stop", sessionID: "fork-child-session")
    assertEventually(firstTab, timeout: Self.coldStartTimeout) {
      $0.label.contains("Done.") && !$0.label.contains("Agent activity:")
    }

    try sendClaudeEvent("session-end", sessionID: "fork-child-session")
    try sendClaudeEvent("session-end", sessionID: "fork-parent-session")
    try assertAgentPanelMenuItem(isEnabled: false)
  }

  @MainActor
  func testSessionStartKeepsAgentIdleUntilPromptSubmit() throws {
    let firstTab = requireFirstTab()

    try sendClaudeEvent("session-start")
    try assertAgentPanelMenuItem(isEnabled: true)
    XCTAssertFalse(firstTab.label.contains("Agent activity:"))

    try sendClaudeEvent("user-prompt-submit")
    assertEventually(firstTab, timeout: Self.coldStartTimeout) {
      $0.label.contains("Agent activity: Running")
    }

    try sendClaudeEvent("stop")
    try sendClaudeEvent("session-end")
    try assertAgentPanelMenuItem(isEnabled: false)
  }

  @MainActor
  func testForkedClaudeSessionRecoversSidebarActivityWithoutSessionStart() throws {
    let firstTab = requireFirstTab()

    try sendClaudeEvent("session-start", sessionID: "parent-session")
    try sendClaudeEvent("user-prompt-submit", sessionID: "forked-session")
    assertEventually(firstTab, timeout: Self.coldStartTimeout) {
      $0.label.contains("Agent activity: Running")
    }

    try sendClaudeEvent("stop", sessionID: "forked-session")
    assertEventually(firstTab, timeout: Self.coldStartTimeout) {
      $0.label.contains("Done.") && !$0.label.contains("Agent activity:")
    }
  }

  @MainActor
  private func requireFirstTab() -> XCUIElement {
    let terminal = mainTerminal
    assertEventually(terminal, timeout: Self.coldStartTimeout) {
      $0.exists && $0.isHittable
    }

    let firstTab = sidebarTabRows.element(boundBy: 0)
    assertEventually(firstTab, timeout: Self.coldStartTimeout) {
      $0.exists && $0.isHittable
    }
    return firstTab
  }

  @MainActor
  private var agentPanel: XCUIElement {
    element("agent-panel")
  }

  @MainActor
  private func selectTab(_ tab: XCUIElement) {
    tab.click()
    assertEventually(tab, timeout: Self.coldStartTimeout) { $0.isSelected }
  }

  @MainActor
  private func assertAgentPanelMenuItem(isEnabled: Bool) throws {
    let identifier = SupatermUITestIdentifier.MenuItemIdentifier.toggleAgentPanel
    let topLevelMenu = app.menuBars.menuBarItems[identifier.menuTitle]
    assertEventually(topLevelMenu, timeout: Self.coldStartTimeout) {
      $0.exists && $0.isHittable
    }
    topLevelMenu.click()

    let item = menuItem(identifier)
    assertEventually(item, timeout: Self.coldStartTimeout) { $0.exists }
    assertEventually(item, timeout: Self.coldStartTimeout) { $0.isEnabled == isEnabled }
    app.typeKey(.escape, modifierFlags: [])
  }

  @MainActor
  private func sendClaudeEvent(
    _ event: String,
    sessionID: String = AgentPanelUITests.sessionID
  ) throws {
    let terminal = mainTerminal
    assertEventually(terminal, timeout: Self.coldStartTimeout) {
      $0.exists && $0.isHittable
    }

    terminal.click()
    terminal.typeText(
      "\"$SUPATERM_CLI_PATH\" internal dev claude \(event)"
        + " --socket \"$SUPATERM_SOCKET_PATH\" --session-id \(sessionID)"
    )
    terminal.typeKey(.return, modifierFlags: [])

    let expectedOutput = "sent \(event) for session \(sessionID)"
    assertEventually(terminal, timeout: Self.coldStartTimeout) {
      ($0.value as? String)?.contains(expectedOutput) == true
    }
  }

  @MainActor
  private func assertEventually(
    _ element: XCUIElement,
    timeout: TimeInterval = 10,
    file: StaticString = #filePath,
    line: UInt = #line,
    until condition: @escaping (XCUIElement) -> Bool
  ) {
    let didMatch = wait(for: element, timeout: timeout, until: condition)
    XCTAssertTrue(didMatch, file: file, line: line)
  }

}
