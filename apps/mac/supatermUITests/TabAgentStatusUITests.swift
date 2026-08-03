import XCTest

final class TabAgentStatusUITests: SupatermUITestCase {
  private static let coldStartTimeout: Duration = .seconds(60)
  private static let sessionID = "pinned-status-lane"

  @MainActor
  func testPinnedTabShowsPinIndicatorUntilAgentActivityTakesTheSlot() async throws {
    await requireInitialSidebarTab()
    try await renameSelectedTab(to: "Slot Lane Tab")

    let row = sidebarTabRow(named: "Slot Lane Tab")
    XCTAssertFalse(row.label.contains("Pinned"))

    try clickSidebarContextMenuItem("Pin Tab", on: row)
    let didMoveToPinned = await wait(for: row) { $0.label.contains("Pinned") }
    XCTAssertTrue(didMoveToPinned)

    mainTerminal.click()
    let didShowPinned = await wait(for: row) { $0.label.contains("Pinned") }
    XCTAssertTrue(didShowPinned)

    try await sendClaudeEvent("session-start")
    try await sendClaudeEvent("user-prompt-submit")

    let didShowRunning = await wait(for: row, timeout: Self.coldStartTimeout) {
      $0.label.contains("Agent activity: Running") && !$0.label.contains("Pinned")
    }
    XCTAssertTrue(didShowRunning)

    try await sendClaudeEvent("stop")
    let didBecomeIdle = await wait(for: row, timeout: Self.coldStartTimeout) {
      !$0.label.contains("Agent activity:")
    }
    XCTAssertTrue(didBecomeIdle)
    mainTerminal.click()
    let didRestorePinned = await wait(for: row, timeout: Self.coldStartTimeout) {
      $0.label.contains("Pinned") && !$0.label.contains("Agent activity:")
    }
    XCTAssertTrue(didRestorePinned)

    try await sendClaudeEvent("session-end")
  }

  @MainActor
  private func sendClaudeEvent(_ event: String) async throws {
    let terminal = mainTerminal
    let didBecomeHittable = await wait(for: terminal, timeout: Self.coldStartTimeout) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didBecomeHittable)

    terminal.click()
    terminal.typeText(
      "\"$SUPATERM_CLI_PATH\" internal dev claude \(event)"
        + " --socket \"$SUPATERM_SOCKET_PATH\" --session-id \(Self.sessionID)"
    )
    terminal.typeKey(.return, modifierFlags: [])

    let expectedOutput = "sent \(event) for session \(Self.sessionID)"
    let didSend = await wait(for: terminal, timeout: Self.coldStartTimeout) {
      ($0.value as? String)?.contains(expectedOutput) == true
    }
    XCTAssertTrue(didSend)
  }
}
