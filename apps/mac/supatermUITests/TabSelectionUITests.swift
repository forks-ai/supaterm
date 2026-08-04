import XCTest

final class TabSelectionUITests: SupatermUITestCase {
  private static let coldStartTimeout: Duration = .seconds(60)

  @MainActor
  func testClosingSelectedTabSelectsNextTabThenPreviousWhenLast() async throws {
    try await createNamedTabs(["First UI Tab", "Second UI Tab", "Third UI Tab"])

    let firstTab = sidebarTabRow(named: "First UI Tab")
    let secondTab = sidebarTabRow(named: "Second UI Tab")
    let thirdTab = sidebarTabRow(named: "Third UI Tab")
    XCTAssertTrue(thirdTab.isSelected)

    try clickMenuItem(.previousTab)
    let didSelectSecondTab = await waitForSidebarSelection(secondTab)
    XCTAssertTrue(didSelectSecondTab)

    try closeSelectedTab()
    let didCloseSecondTab = await waitForSidebarElementCount(
      sidebarTabRows,
      equals: 2,
      timeout: .seconds(30)
    )
    XCTAssertTrue(didCloseSecondTab)
    let didSelectThirdTab = await waitForSidebarSelection(thirdTab)
    XCTAssertTrue(didSelectThirdTab)
    XCTAssertFalse(firstTab.isSelected)

    try closeSelectedTab()
    let didCloseThirdTab = await waitForSidebarElementCount(
      sidebarTabRows,
      equals: 1,
      timeout: .seconds(30)
    )
    XCTAssertTrue(didCloseThirdTab)
    let didSelectFirstTab = await waitForSidebarSelection(firstTab)
    XCTAssertTrue(didSelectFirstTab)
  }

  @MainActor
  func testSelectingTabFocusesLatestUnreadPane() async throws {
    let initialPanes = try await requireVisiblePanes(count: 1)
    let paneAIdentifier = initialPanes[0].identifier

    try clickMenuItem(.splitRight)
    let panes = try await requireVisiblePanes(count: 2)
    let paneA = try XCTUnwrap(panes.first { $0.identifier == paneAIdentifier })
    let paneB = try XCTUnwrap(panes.max { $0.frame.midX < $1.frame.midX })
    let panePrefix = SupatermUITestIdentifier.Accessibility.terminalPanePrefix
    let paneBID = String(paneB.identifier.dropFirst(panePrefix.count))

    try clickMenuItem(.selectSplitLeft)
    try await requireFocus(on: paneA)

    paneA.typeText(
      "\"$SUPATERM_CLI_PATH\" pane notify \(paneBID) --body unread-pane-marker"
        + " --socket \"$SUPATERM_SOCKET_PATH\""
    )
    paneA.typeKey(.return, modifierFlags: [])
    let didCompleteNotification = await wait(for: paneA, timeout: Self.coldStartTimeout) {
      ($0.value as? String)?.contains("window 1 space 1 tab 1 pane 2") == true
    }
    XCTAssertTrue(didCompleteNotification)

    let firstTab = sidebarTabRows.element(boundBy: 0)
    let didRegisterUnread = await wait(for: firstTab, timeout: Self.coldStartTimeout) {
      $0.label.contains("unread-pane-marker")
    }
    XCTAssertTrue(didRegisterUnread)

    try clickMenuItem(.newTab)
    let secondTab = sidebarTabRows.element(boundBy: 1)
    let didSelectSecondTab = await wait(for: secondTab, timeout: Self.coldStartTimeout) {
      $0.exists && $0.isHittable && $0.isSelected
    }
    XCTAssertTrue(didSelectSecondTab)

    firstTab.click()
    let didSelectFirstTab = await waitForSidebarSelection(firstTab)
    XCTAssertTrue(didSelectFirstTab)
    try await requireFocus(on: paneB)
    XCTAssertFalse(focusedTerminalPane(identifier: paneA.identifier).exists)

    let didClearUnread = await wait(for: firstTab, timeout: Self.coldStartTimeout) {
      !$0.label.contains("unread-pane-marker")
    }
    XCTAssertTrue(didClearUnread)
  }
}
