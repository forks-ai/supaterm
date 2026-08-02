import XCTest

final class CommandPaletteUITests: SupatermUITestCase {
  @MainActor
  func testShortcutFocusesInputAndEscapeRestoresTerminalFocus() throws {
    let terminal = try readyTerminal()
    terminal.click()
    let terminalValue = try XCTUnwrap(terminal.value as? String)

    let input = try openPalette()
    let query = "toggle side"
    app.typeText(query)

    let didFocusInput = wait(for: input) {
      $0.value as? String == query
    }
    XCTAssertTrue(didFocusInput)
    XCTAssertEqual(terminal.value as? String, terminalValue)

    app.typeKey(.escape, modifierFlags: [])

    let didDismiss = wait(for: input) { !$0.exists }
    XCTAssertTrue(didDismiss)

    let focusedTerminal = app.textViews.matching(keyboardFocusPredicate).firstMatch
    let didRestoreTerminalFocus = wait(for: focusedTerminal) { $0.exists }
    XCTAssertTrue(didRestoreTerminalFocus)

    let terminalInput = "palette focus restored"
    app.typeText(terminalInput)

    let didTypeInTerminal = wait(for: terminal) {
      $0.value as? String == terminalValue + terminalInput
    }
    XCTAssertTrue(didTypeInTerminal)
  }

  @MainActor
  func testTypingPartialQueryFiltersRowsAndHandlesEmptyResults() throws {
    let terminal = try readyTerminal()
    terminal.click()
    let input = try openPalette()
    let rows = paletteRows

    input.typeText("tOgGlE sIdE")

    let didFilter = wait(for: rows.firstMatch) {
      $0.exists && rows.count == 1
    }
    XCTAssertTrue(didFilter)
    XCTAssertTrue(rows.firstMatch.label.contains("Toggle Sidebar"))

    app.typeKey("a", modifierFlags: .command)
    app.typeText("zzzzzzzzzz")

    let noMatches = app.staticTexts["No matches"]
    let didShowEmptyState = wait(for: noMatches) {
      $0.exists && !rows.firstMatch.exists
    }
    XCTAssertTrue(didShowEmptyState)

    app.typeKey(.downArrow, modifierFlags: [])
    app.typeKey(.return, modifierFlags: [])

    let didKeepEmptyPaletteOpen = wait(for: focusedPaletteInput) {
      $0.exists && input.value as? String == "zzzzzzzzzz"
    }
    XCTAssertTrue(didKeepEmptyPaletteOpen)
  }

  @MainActor
  func testArrowKeysMoveSelectionBetweenRows() throws {
    let terminal = try readyTerminal()
    terminal.click()
    let input = try openPalette()
    let rows = paletteRows

    input.typeText("Space")

    let firstRow = rows.element(boundBy: 0)
    let secondRow = rows.element(boundBy: 1)
    let didShowSpaceRows = wait(for: secondRow) {
      $0.exists && rows.count == 2
    }
    XCTAssertTrue(didShowSpaceRows)
    XCTAssertTrue(firstRow.label.contains("Create Space"))
    XCTAssertTrue(secondRow.label.contains("Edit Space"))

    let didSelectFirstRow = wait(for: firstRow) { $0.isSelected }
    XCTAssertTrue(didSelectFirstRow)
    XCTAssertFalse(secondRow.isSelected)

    app.typeKey(.downArrow, modifierFlags: [])

    let didSelectSecondRow = wait(for: secondRow) {
      $0.isSelected && !firstRow.isSelected
    }
    XCTAssertTrue(didSelectSecondRow)

    app.typeKey(.upArrow, modifierFlags: [])

    let didReturnToFirstRow = wait(for: firstRow) {
      $0.isSelected && !secondRow.isSelected
    }
    XCTAssertTrue(didReturnToFirstRow)
  }

  @MainActor
  func testToggleSidebarCommandHidesAndRestoresSidebar() throws {
    let terminal = try readyTerminal()
    terminal.click()
    let sidebarRow = sidebarTabRows.firstMatch

    try executePaletteCommand("Toggle Sidebar")

    let didHideSidebar = wait(for: sidebarRow) { !$0.isHittable }
    XCTAssertTrue(didHideSidebar)

    try executePaletteCommand("Toggle Sidebar")

    let didRestoreSidebar = wait(for: sidebarRow) { $0.isHittable }
    XCTAssertTrue(didRestoreSidebar)
  }

  @MainActor
  func testCreateSpaceCommandDisplaysNewSpaceInTheSameWindow() throws {
    let terminal = try readyTerminal()
    terminal.click()

    try executePaletteCommand("Create Space")

    let nameField = app.textFields[
      SupatermUITestIdentifier.Accessibility.dialogSpaceName
    ]
    XCTAssertTrue(nameField.waitForExistence(timeout: 10))
    nameField.click()

    let spaceName = "Palette UI Test"
    nameField.typeText(spaceName)

    let confirmButton = app.buttons[
      SupatermUITestIdentifier.Accessibility.dialogConfirm
    ]
    let didEnableConfirm = wait(for: confirmButton) {
      $0.exists && $0.isEnabled
    }
    XCTAssertTrue(didEnableConfirm)
    confirmButton.click()

    let didDisplayCreatedSpace = waitForDisplayedSpace(named: spaceName)
    XCTAssertTrue(didDisplayCreatedSpace)

    let didAddSpaceDot = waitForSidebarElementCount(spaceDots, equals: 2)
    XCTAssertTrue(didAddSpaceDot)
    XCTAssertEqual(app.windows.count, 1)
  }

  @MainActor
  func testPinTabCommandMovesCurrentTabToPinnedSection() throws {
    let terminal = try readyTerminal()
    terminal.click()

    let rows = sidebarTabRows
    XCTAssertEqual(rows.count, 1)
    XCTAssertFalse(rows.firstMatch.label.contains("Pinned"))

    try executePaletteCommand("Pin Tab")

    let didMoveTab = wait(for: rows.firstMatch) {
      $0.exists && $0.label.contains("Pinned") && rows.count == 1
    }
    XCTAssertTrue(didMoveTab)
  }

  @MainActor
  private var paletteRows: XCUIElementQuery {
    app.buttons.matching(
      identifier: SupatermUITestIdentifier.Accessibility.paletteResultRow
    )
  }

  @MainActor
  private var focusedPaletteInput: XCUIElement {
    app.textFields
      .matching(identifier: SupatermUITestIdentifier.Accessibility.paletteInput)
      .matching(keyboardFocusPredicate)
      .firstMatch
  }

  private var keyboardFocusPredicate: NSPredicate {
    NSPredicate(format: "hasKeyboardFocus == true")
  }

  @MainActor
  private func readyTerminal() throws -> XCUIElement {
    _ = mainWindow

    let sidebarRow = sidebarTabRows.firstMatch
    try require(sidebarRow, timeout: 30, "Initial sidebar tab row did not appear")

    let terminal = app.textViews.firstMatch
    return try require(terminal, timeout: 30, "Terminal did not appear")
  }

  @MainActor
  private func openPalette() throws -> XCUIElement {
    app.typeKey("p", modifierFlags: [.command, .shift])

    let input = app.textFields[
      SupatermUITestIdentifier.Accessibility.paletteInput
    ]
    let existingInput = try require(input, "Command palette input did not appear")
    let didFocus = wait(for: focusedPaletteInput) { $0.exists }
    return try XCTUnwrap(
      didFocus ? existingInput : nil,
      "Command palette input did not receive keyboard focus"
    )
  }

  @MainActor
  private func executePaletteCommand(_ title: String) throws {
    let input = try openPalette()
    input.typeText(title)

    let rows = paletteRows
    let didFilterToCommand = wait(for: rows.firstMatch) {
      $0.exists && rows.count == 1
    }
    XCTAssertTrue(didFilterToCommand)
    XCTAssertTrue(rows.firstMatch.label.contains(title))

    app.typeKey(.return, modifierFlags: [])

    let didDismiss = wait(for: input) { !$0.exists }
    XCTAssertTrue(didDismiss)
  }
}
