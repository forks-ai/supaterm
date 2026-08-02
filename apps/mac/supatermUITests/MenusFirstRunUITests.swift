import XCTest

final class MenusFirstRunUITests: SupatermUITestCase {
  @MainActor
  func testPinMenuFollowsSelectedTabState() throws {
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

    let didMoveToPinnedSection = wait(for: tabRow) { row in
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
  func testSecondSpaceMenuItemBecomesEnabledAfterCreatingSpace() throws {
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

    let didCreateSecondSpace = waitForDisplayedSpace(
      named: "Second",
      timeout: 30
    )
    XCTAssertTrue(didCreateSecondSpace)

    try openMenu("Spaces")
    let didEnableSecondSpace = wait(for: secondSpace) {
      $0.exists && $0.isEnabled
    }
    XCTAssertTrue(didEnableSecondSpace)
  }

  @MainActor
  func testOnlyFirstLaunchRunsOnboarding() throws {
    try relaunch(removing: ["launch-state.json", "session.json"])

    _ = mainWindow

    let firstTerminal = app.textViews.firstMatch
    XCTAssertTrue(firstTerminal.waitForExistence(timeout: 30))
    let didRenderOnboarding = wait(
      for: firstTerminal,
      timeout: 30
    ) { terminal in
      (terminal.value as? String)?.contains("Welcome to Supaterm!") == true
    }
    XCTAssertTrue(didRenderOnboarding)

    let launchState = stateHome.appendingPathComponent("launch-state.json")
    let didPersistLaunchState = waitForFile(at: launchState)
    XCTAssertTrue(didPersistLaunchState)

    try relaunch(removing: ["session.json"])

    let secondTerminal = app.textViews.firstMatch
    XCTAssertTrue(secondTerminal.waitForExistence(timeout: 30))
    secondTerminal.click()
    app.typeText("/usr/bin/printf 'second-launch-%s\\n' ready\n")

    let didStartShell = wait(
      for: secondTerminal,
      timeout: 30
    ) { terminal in
      (terminal.value as? String)?.contains("second-launch-ready") == true
    }
    XCTAssertTrue(didStartShell)
    XCTAssertFalse((secondTerminal.value as? String)?.contains("Welcome to Supaterm!") == true)
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

  @MainActor
  private func waitForFile(
    at url: URL,
    timeout: TimeInterval = 10
  ) -> Bool {
    wait(timeout: timeout) {
      FileManager.default.fileExists(atPath: url.path)
    }
  }
}
