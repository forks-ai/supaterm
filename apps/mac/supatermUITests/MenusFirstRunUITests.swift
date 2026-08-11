import XCTest

final class MenusFirstRunUITests: SupatermUITestCase {
  @MainActor
  func testPinMenuFollowsSelectedTabState() async throws {
    _ = mainWindow

    let tabRow = sidebarTabRows.firstMatch
    guard tabRow.waitForExistence(timeout: 30) else {
      XCTFail("Initial sidebar tab row did not appear")
      return
    }

    tabRow.rightClick()
    let pin = app.menuItems["Pin Tab"]
    XCTAssertTrue(pin.waitForExistence(timeout: 10))
    XCTAssertTrue(pin.isEnabled)
    XCTAssertFalse(app.menuItems["Unpin Tab"].exists)
    pin.click()

    let didMoveToPinnedSection = await wait(for: tabRow) { row in
      row.exists && row.label.contains("Pinned")
    }
    XCTAssertTrue(didMoveToPinnedSection)

    tabRow.rightClick()
    let unpin = app.menuItems["Unpin Tab"]
    XCTAssertTrue(unpin.waitForExistence(timeout: 10))
    XCTAssertTrue(unpin.isEnabled)
    XCTAssertFalse(pin.exists)
  }

  @MainActor
  func testSecondSpaceMenuItemBecomesEnabledAfterCreatingSpace() async throws {
    _ = mainWindow

    try openMenu("Spaces")
    let secondSpace = rawMenuItem(
      SupatermUITestIdentifier.MenuItemIdentifier.secondSpace.rawValue
    )
    XCTAssertTrue(secondSpace.waitForExistence(timeout: 10))
    XCTAssertFalse(secondSpace.isEnabled)
    app.typeKey(.escape, modifierFlags: [])

    let terminal = app.textViews.firstMatch
    XCTAssertTrue(terminal.waitForExistence(timeout: 30))
    terminal.click()
    app.typeText("sp space new Second\n")

    let didCreateSecondSpace = await waitForDisplayedSpace(
      named: "Second",
      timeout: .seconds(30)
    )
    XCTAssertTrue(didCreateSecondSpace)

    try openMenu("Spaces")
    let didEnableSecondSpace = await wait(for: secondSpace) {
      $0.exists && $0.isEnabled
    }
    XCTAssertTrue(didEnableSecondSpace)
  }

  @MainActor
  private func openMenu(_ title: String) throws {
    let menu = app.menuBars.menuBarItems[title]
    try require(menu)
    menu.click()
  }

  @MainActor
  private func rawMenuItem(_ identifier: String) -> XCUIElement {
    app.menuItems.matching(identifier: identifier).firstMatch
  }

}
