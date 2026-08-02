import XCTest

final class TabsSpacesUITests: SupatermUITestCase {
  private static let paneIdentifierPrefix = "terminal.pane."
  private static let coldStartTimeout: TimeInterval = 60
  private static let pinnedStatusSessionID = "pinned-status-lane"

  @MainActor
  func testNewAndCloseTabUpdateSidebarRows() throws {
    _ = mainWindow
    let didShowInitialTab = waitForSidebarElementCount(tabRows, equals: 1, timeout: 30)
    XCTAssertTrue(didShowInitialTab)

    try clickMenuItem(.newTab)

    let didCreateTab = waitForSidebarElementCount(tabRows, equals: 2, timeout: 30)
    XCTAssertTrue(didCreateTab)

    try closeSelectedTab()

    let didCloseTab = waitForSidebarElementCount(tabRows, equals: 1, timeout: 30)
    XCTAssertTrue(didCloseTab)
  }

  @MainActor
  func testChangingTabTitleUpdatesSidebarRow() throws {
    _ = mainWindow
    let didShowInitialTab = waitForSidebarElementCount(tabRows, equals: 1, timeout: 30)
    XCTAssertTrue(didShowInitialTab)

    let title = "Renamed UI Tab"
    try renameSelectedTab(to: title)

    XCTAssertTrue(tabRow(named: title).exists)
  }

  @MainActor
  func testPinAndUnpinMoveTabBetweenSidebarSections() throws {
    _ = mainWindow
    let didShowInitialTab = waitForSidebarElementCount(tabRows, equals: 1, timeout: 30)
    XCTAssertTrue(didShowInitialTab)

    let title = "Lane UI Tab"
    try renameSelectedTab(to: title)

    let didShowRegularTab = wait(for: tabRow(named: title)) {
      $0.exists && !$0.label.contains("Pinned")
    }
    XCTAssertTrue(didShowRegularTab)

    try clickSidebarContextMenuItem("Pin Tab", on: tabRow(named: title))

    let didMoveToPinned = wait(for: tabRow(named: title)) {
      $0.label.contains("Pinned")
    }
    XCTAssertTrue(didMoveToPinned)

    try clickSidebarContextMenuItem("Unpin Tab", on: tabRow(named: title))

    let didMoveToRegular = wait(for: tabRow(named: title)) {
      $0.exists && !$0.label.contains("Pinned")
    }
    XCTAssertTrue(didMoveToRegular)
  }

  @MainActor
  func testCreateSwitchRenameAndDeleteSpace() throws {
    _ = mainWindow
    let didShowInitialTab = waitForSidebarElementCount(tabRows, equals: 1, timeout: 30)
    XCTAssertTrue(didShowInitialTab)
    XCTAssertEqual(spaceDots.count, 1)

    try createSpace(named: "UI Space")

    let didDisplayCreatedSpace = waitForDisplayedSpace(named: "UI Space")
    XCTAssertTrue(didDisplayCreatedSpace)
    let didAddSpaceDot = waitForSidebarElementCount(spaceDots, equals: 2)
    XCTAssertTrue(didAddSpaceDot)
    XCTAssertEqual(app.windows.count, 1)

    app.typeKey("1", modifierFlags: .control)

    let didDisplayInitialSpace = waitForDisplayedSpace(named: "Space 1")
    XCTAssertTrue(didDisplayInitialSpace)

    let createdSpaceDot = spaceDot(named: "UI Space")
    if !createdSpaceDot.isHittable {
      try require(app.buttons["Enter full screen"]).click()
    }
    let didMakeCreatedSpaceDotHittable = wait(for: createdSpaceDot) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didMakeCreatedSpaceDotHittable)
    try require(createdSpaceDot).click()

    let didReturnToCreatedSpace = waitForDisplayedSpace(named: "UI Space")
    XCTAssertTrue(didReturnToCreatedSpace)

    displayedSpace.click()
    let renameSpace = app.menuItems["Edit Space"]
    XCTAssertTrue(renameSpace.waitForExistence(timeout: 10))
    renameSpace.click()

    let nameField = app.textFields[
      SupatermUITestIdentifier.Accessibility.dialogSpaceName
    ]
    XCTAssertTrue(nameField.waitForExistence(timeout: 10))
    nameField.click()
    nameField.typeKey("a", modifierFlags: .command)
    nameField.typeText("Renamed UI Space")

    let greenSwatch = app.buttons[
      SupatermUITestIdentifier.Accessibility.dialogSpaceColorPrefix + "green"
    ]
    XCTAssertTrue(greenSwatch.waitForExistence(timeout: 10))
    greenSwatch.click()

    let confirm = app.buttons[
      SupatermUITestIdentifier.Accessibility.dialogConfirm
    ]
    XCTAssertTrue(confirm.waitForExistence(timeout: 10))
    confirm.click()

    let didRenameSpace = waitForDisplayedSpace(named: "Renamed UI Space")
    XCTAssertTrue(didRenameSpace)
    XCTAssertFalse(spaceDot(named: "UI Space").exists)

    displayedSpace.click()
    let deleteSpace = app.menuItems["Delete Space"]
    XCTAssertTrue(deleteSpace.waitForExistence(timeout: 10))
    deleteSpace.click()

    let deleteSheet = app.sheets.firstMatch
    XCTAssertTrue(deleteSheet.waitForExistence(timeout: 10))
    let deleteTitle = deleteSheet.staticTexts["Delete Space \"Renamed UI Space\"?"]
    XCTAssertTrue(deleteTitle.waitForExistence(timeout: 10))
    let deleteButton = deleteSheet.buttons["Delete"]
    XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
    deleteButton.click()

    let didDisplayNeighborSpace = waitForDisplayedSpace(named: "Space 1")
    XCTAssertTrue(didDisplayNeighborSpace)
    let didRemoveSpaceDot = waitForSidebarElementCount(spaceDots, equals: 1)
    XCTAssertTrue(didRemoveSpaceDot)
    XCTAssertFalse(spaceDot(named: "Renamed UI Space").exists)
    XCTAssertEqual(app.windows.count, 1)
  }

  @MainActor
  func testTabNavigationUpdatesSelectedSidebarRow() throws {
    try createNamedTabs(["First UI Tab", "Second UI Tab", "Third UI Tab"])

    let firstTab = tabRow(named: "First UI Tab")
    let secondTab = tabRow(named: "Second UI Tab")
    let thirdTab = tabRow(named: "Third UI Tab")
    XCTAssertTrue(thirdTab.isSelected)

    try clickMenuItem(.nextTab)

    let didSelectFirstTab = waitForSidebarSelection(firstTab)
    XCTAssertTrue(didSelectFirstTab)

    try clickMenuItem(.selectLastTab)

    let didSelectLastTab = waitForSidebarSelection(thirdTab)
    XCTAssertTrue(didSelectLastTab)

    try clickMenuItem(.previousTab)

    let didSelectPreviousTab = waitForSidebarSelection(secondTab)
    XCTAssertTrue(didSelectPreviousTab)
  }

  @MainActor
  func testClosingSelectedTabSelectsNextTabThenPreviousWhenLast() throws {
    try createNamedTabs(["First UI Tab", "Second UI Tab", "Third UI Tab"])

    let firstTab = tabRow(named: "First UI Tab")
    let secondTab = tabRow(named: "Second UI Tab")
    let thirdTab = tabRow(named: "Third UI Tab")
    XCTAssertTrue(thirdTab.isSelected)

    try clickMenuItem(.previousTab)
    let didSelectSecondTab = waitForSidebarSelection(secondTab)
    XCTAssertTrue(didSelectSecondTab)

    try closeSelectedTab()
    let didCloseSecondTab = waitForSidebarElementCount(tabRows, equals: 2, timeout: 30)
    XCTAssertTrue(didCloseSecondTab)
    let didSelectThirdTab = waitForSidebarSelection(thirdTab)
    XCTAssertTrue(didSelectThirdTab)
    XCTAssertFalse(firstTab.isSelected)

    try closeSelectedTab()
    let didCloseThirdTab = waitForSidebarElementCount(tabRows, equals: 1, timeout: 30)
    XCTAssertTrue(didCloseThirdTab)
    let didSelectFirstTab = waitForSidebarSelection(firstTab)
    XCTAssertTrue(didSelectFirstTab)
  }

  @MainActor
  func testSelectingTabFocusesLatestUnreadPane() throws {
    let initialPanes = try requireVisiblePanes(count: 1)
    let paneAIdentifier = initialPanes[0].identifier

    try clickMenuItem(.splitRight)
    let panes = try requireVisiblePanes(count: 2)
    let paneA = try XCTUnwrap(panes.first { $0.identifier == paneAIdentifier })
    let paneB = try XCTUnwrap(panes.max { $0.frame.midX < $1.frame.midX })
    let paneBID = String(paneB.identifier.dropFirst(Self.paneIdentifierPrefix.count))

    try clickMenuItem(.selectSplitLeft)
    try requireFocus(on: paneA)

    paneA.typeText(
      "\"$SUPATERM_CLI_PATH\" pane notify \(paneBID) --body unread-pane-marker"
        + " --socket \"$SUPATERM_SOCKET_PATH\""
    )
    paneA.typeKey(.return, modifierFlags: [])
    let didCompleteNotification = wait(for: paneA, timeout: Self.coldStartTimeout) {
      ($0.value as? String)?.contains("window 1 space 1 tab 1 pane 2") == true
    }
    XCTAssertTrue(didCompleteNotification)

    let firstTab = tabRows.element(boundBy: 0)
    let didRegisterUnread = wait(for: firstTab, timeout: Self.coldStartTimeout) {
      $0.label.contains("unread-pane-marker")
    }
    XCTAssertTrue(didRegisterUnread)

    try clickMenuItem(.newTab)
    let secondTab = tabRows.element(boundBy: 1)
    let didSelectSecondTab = wait(for: secondTab, timeout: Self.coldStartTimeout) {
      $0.exists && $0.isHittable && $0.isSelected
    }
    XCTAssertTrue(didSelectSecondTab)

    firstTab.click()
    let didSelectFirstTab = waitForSidebarSelection(firstTab)
    XCTAssertTrue(didSelectFirstTab)
    try requireFocus(on: paneB)
    XCTAssertFalse(focusedTerminalPane(identifier: paneA.identifier).exists)

    let didClearUnread = wait(for: firstTab, timeout: Self.coldStartTimeout) {
      !$0.label.contains("unread-pane-marker")
    }
    XCTAssertTrue(didClearUnread)
  }

  @MainActor
  func testPinnedTabShowsPinIndicatorUntilAgentActivityTakesTheSlot() throws {
    _ = mainWindow
    let didShowInitialTab = waitForSidebarElementCount(tabRows, equals: 1, timeout: 30)
    XCTAssertTrue(didShowInitialTab)
    try renameSelectedTab(to: "Slot Lane Tab")

    let row = tabRow(named: "Slot Lane Tab")
    XCTAssertFalse(row.label.contains("Pinned"))

    try clickSidebarContextMenuItem("Pin Tab", on: row)
    let didMoveToPinned = wait(for: row) { $0.label.contains("Pinned") }
    XCTAssertTrue(didMoveToPinned)

    mainTerminal.click()
    let didShowPinned = wait(for: row) { $0.label.contains("Pinned") }
    XCTAssertTrue(didShowPinned)

    try sendClaudeEvent("session-start")
    try sendClaudeEvent("user-prompt-submit")

    let didShowRunning = wait(for: row, timeout: Self.coldStartTimeout) {
      $0.label.contains("Agent activity: Running") && !$0.label.contains("Pinned")
    }
    XCTAssertTrue(didShowRunning)

    try sendClaudeEvent("stop")
    let didBecomeIdle = wait(for: row, timeout: Self.coldStartTimeout) {
      !$0.label.contains("Agent activity:")
    }
    XCTAssertTrue(didBecomeIdle)
    mainTerminal.click()
    let didRestorePinned = wait(for: row, timeout: Self.coldStartTimeout) {
      $0.label.contains("Pinned") && !$0.label.contains("Agent activity:")
    }
    XCTAssertTrue(didRestorePinned)

    try sendClaudeEvent("session-end")
  }

  @MainActor
  func testNewTabAppendsAtEndWhenMiddleTabSelected() throws {
    try createNamedTabs(["First UI Tab", "Second UI Tab", "Third UI Tab"])

    let secondTab = tabRow(named: "Second UI Tab")
    try clickMenuItem(.previousTab)
    let didSelectSecondTab = waitForSidebarSelection(secondTab)
    XCTAssertTrue(didSelectSecondTab)

    try clickMenuItem(.newTab)
    let didCreateFourthTab = waitForSidebarElementCount(tabRows, equals: 4, timeout: 30)
    XCTAssertTrue(didCreateFourthTab)
    try renameSelectedTab(to: "Fourth UI Tab")

    let expectedOrder = ["First UI Tab", "Second UI Tab", "Third UI Tab", "Fourth UI Tab"]
    let didAppendAtEnd = waitForTabOrder(expectedOrder)
    XCTAssertTrue(didAppendAtEnd)
    XCTAssertTrue(tabRow(named: "Fourth UI Tab").isSelected)
  }

  @MainActor
  func testDraggingTabReordersRegularSectionAndPinsAcrossSections() throws {
    try createNamedTabs(["First UI Tab", "Second UI Tab", "Third UI Tab"])

    let reorderedTitles = ["Second UI Tab", "Third UI Tab", "First UI Tab"]
    let didReorder = dragTab(
      source: tabRow(named: "First UI Tab"),
      destination: tabRow(named: "Third UI Tab"),
      destinationY: 0.9,
      until: { self.tabRowsMatch(reorderedTitles) }
    )
    XCTAssertTrue(didReorder)

    let secondTab = tabRow(named: "Second UI Tab")
    try clickSidebarContextMenuItem("Pin Tab", on: secondTab)
    let didPinSecondTab = wait(for: secondTab) { $0.label.contains("Pinned") }
    XCTAssertTrue(didPinSecondTab)

    let thirdTabInRegularSection = tabRow(named: "Third UI Tab")
    let didPinThirdTab = dragTab(
      source: thirdTabInRegularSection,
      destination: secondTab,
      destinationY: 0.1,
      until: { thirdTabInRegularSection.label.contains("Pinned") }
    )
    XCTAssertTrue(didPinThirdTab)
  }

  @MainActor
  private var tabRows: XCUIElementQuery { sidebarTabRows }

  @MainActor
  private var terminalPanes: XCUIElementQuery {
    app.textViews.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", Self.paneIdentifierPrefix)
    )
  }

  @MainActor
  private var focusedTerminalPanes: XCUIElementQuery {
    terminalPanes.matching(NSPredicate(format: "hasKeyboardFocus == true"))
  }

  @MainActor
  private func tabRow(named title: String) -> XCUIElement { sidebarTabRow(named: title) }

  @MainActor
  private func closeSelectedTab() throws {
    try clickMenuItem(.closeTab)

    let closeSheet = mainWindow.sheets.firstMatch
    XCTAssertTrue(closeSheet.waitForExistence(timeout: 10))
    let closeButton = closeSheet.buttons["Close"]
    XCTAssertTrue(closeButton.waitForExistence(timeout: 10))
    closeButton.click()
  }

  @MainActor
  private func sendClaudeEvent(_ event: String) throws {
    let terminal = mainTerminal
    let didBecomeHittable = wait(for: terminal, timeout: Self.coldStartTimeout) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didBecomeHittable)

    terminal.click()
    terminal.typeText(
      "\"$SUPATERM_CLI_PATH\" internal dev claude \(event)"
        + " --socket \"$SUPATERM_SOCKET_PATH\" --session-id \(Self.pinnedStatusSessionID)"
    )
    terminal.typeKey(.return, modifierFlags: [])

    let expectedOutput = "sent \(event) for session \(Self.pinnedStatusSessionID)"
    let didSend = wait(for: terminal, timeout: Self.coldStartTimeout) {
      ($0.value as? String)?.contains(expectedOutput) == true
    }
    XCTAssertTrue(didSend)
  }

  @MainActor
  private func requireVisiblePanes(count expectedCount: Int) throws -> [XCUIElement] {
    let didReachCount = wait(for: mainWindow, timeout: 30) { _ in
      guard self.terminalPanes.count == expectedCount else { return false }
      return (0..<expectedCount).allSatisfy {
        let pane = self.terminalPanes.element(boundBy: $0)
        return pane.exists && !pane.frame.isEmpty
      }
    }
    return try XCTUnwrap(
      didReachCount
        ? (0..<expectedCount).map { terminalPanes.element(boundBy: $0) }
        : nil,
      "Expected \(expectedCount) visible terminal panes"
    )
  }

  @MainActor
  private func requireFocus(on pane: XCUIElement) throws {
    let focusedPane = focusedTerminalPane(identifier: pane.identifier)
    let didFocus = wait(for: focusedPane) { $0.exists }
    XCTAssertTrue(didFocus, "Expected pane \(pane.identifier) to have keyboard focus")
  }

  @MainActor
  private func focusedTerminalPane(identifier: String) -> XCUIElement {
    focusedTerminalPanes.matching(identifier: identifier).firstMatch
  }

  @MainActor
  private func createSpace(named name: String) throws {
    try require(displayedSpace).click()
    let createSpace = try require(app.menuItems["New Space"])
    createSpace.click()

    let nameFieldCandidate = app.textFields[
      SupatermUITestIdentifier.Accessibility.dialogSpaceName
    ]
    let nameField = try require(nameFieldCandidate)
    nameField.typeText(name)

    let confirmCandidate = app.buttons[
      SupatermUITestIdentifier.Accessibility.dialogConfirm
    ]
    let confirm = try require(confirmCandidate)
    confirm.click()

    let didDismissEditor = wait(for: nameField) { !$0.exists }
    XCTAssertTrue(didDismissEditor)
  }

  @MainActor
  private func tabRowsMatch(_ titles: [String]) -> Bool {
    guard tabRows.count == titles.count else { return false }
    return titles.indices.allSatisfy {
      tabRows.element(boundBy: $0).label.contains(titles[$0])
    }
  }

  @MainActor
  private func dragTab(
    source: XCUIElement,
    destination: XCUIElement,
    destinationY: CGFloat,
    until condition: @escaping () -> Bool
  ) -> Bool {
    for _ in 0..<2 {
      guard source.exists, destination.exists else { return false }

      source.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(
        forDuration: 0.5,
        thenDragTo: destination.coordinate(
          withNormalizedOffset: CGVector(dx: 0.5, dy: destinationY)
        ),
        withVelocity: .slow,
        thenHoldForDuration: 0.5
      )
      if wait(timeout: 10, until: condition) {
        return true
      }
    }
    return condition()
  }
}
