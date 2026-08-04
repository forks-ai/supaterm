import Foundation
import XCTest

final class PaneClosingUITests: SupatermUITestCase {
  @MainActor
  func testExitingShellClosesPaneWithoutConfirmation() async throws {
    _ = try await requireVisiblePanes(count: 1)
    let originalIdentifier = terminalPanes.element(boundBy: 0).identifier

    try clickMenuItem(.splitRight)
    let panes = try await requireVisiblePanes(count: 2)
    let newPane = try XCTUnwrap(panes.first { $0.identifier != originalIdentifier })
    newPane.click()
    try await requireFocus(on: newPane)

    newPane.typeText("exit\n")
    let didClosePane = await wait(for: mainWindow, timeout: .seconds(30)) { _ in
      self.terminalPanes.count == 1
        && self.terminalPanes.element(boundBy: 0).identifier == originalIdentifier
    }
    guard didClosePane else {
      XCTFail("Exited pane did not close while preserving its sibling")
      return
    }

    XCTAssertEqual(mainWindow.sheets.count, 0)
    XCTAssertFalse(
      app.buttons[SupatermUITestIdentifier.Accessibility.dialogConfirm].exists
    )

    let survivor = terminalPanes.element(boundBy: 0)
    try await requireFocus(on: survivor)

    let token = UUID().uuidString.prefix(8)
    app.typeText("echo exit-\"close\"-\(token)\n")
    let survivorReceivedInput = await wait(for: survivor, timeout: .seconds(30)) {
      ($0.value as? String)?.contains("exit-close-\(token)") == true
    }
    XCTAssertTrue(survivorReceivedInput)
  }

  @MainActor
  func testCommandWClosesFocusedPaneNotWindow() async throws {
    try relaunchWithoutCloseConfirmation()

    _ = try await requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try await requireVisiblePanes(count: 2)
    let leftPane = try XCTUnwrap(panes.min { $0.frame.midX < $1.frame.midX })
    let rightPane = try XCTUnwrap(panes.max { $0.frame.midX < $1.frame.midX })
    let leftPaneIdentifier = leftPane.identifier

    rightPane.click()
    try await requireFocus(on: rightPane)
    app.typeKey("w", modifierFlags: .command)

    let survivors = try await requireVisiblePanes(count: 1)
    XCTAssertEqual(survivors[0].identifier, leftPaneIdentifier)
    XCTAssertEqual(mainWindow.sheets.count, 0)
    XCTAssertEqual(app.windows.count, 1)
    XCTAssertTrue(mainWindow.exists)
  }

  @MainActor
  func testClosingBusyPaneRequiresConfirmation() async throws {
    _ = try await requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try await requireVisiblePanes(count: 2)
    let rightPane = try XCTUnwrap(panes.max { $0.frame.midX < $1.frame.midX })
    rightPane.click()
    try await requireFocus(on: rightPane)

    let processSentinel = "pane-busy"
    rightPane.typeText("printf '\\033]0;\(processSentinel)\\007'; sleep 600\n")
    let didStartProcess = await wait(for: rightPane, timeout: .seconds(30)) {
      $0.label == processSentinel
    }
    guard didStartProcess else {
      XCTFail("Busy pane process did not start")
      return
    }

    try clickMenuItem(.closeSurface)

    let cancelButton = mainWindow.sheets.firstMatch.buttons["Cancel"]
    guard cancelButton.waitForExistence(timeout: 10) else {
      XCTFail("Close confirmation did not appear")
      return
    }
    cancelButton.click()
    _ = try await requireVisiblePanes(count: 2)

    rightPane.click()
    try await requireFocus(on: rightPane)
    try clickMenuItem(.closeSurface)

    let confirmButton = mainWindow.sheets.firstMatch.buttons["Close"]
    guard confirmButton.waitForExistence(timeout: 10) else {
      XCTFail("Close confirmation did not reappear")
      return
    }
    confirmButton.click()

    _ = try await requireVisiblePanes(count: 1)
  }
}
