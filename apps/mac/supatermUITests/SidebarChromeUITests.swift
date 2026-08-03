import XCTest

final class SidebarChromeUITests: SupatermUITestCase {
  @MainActor
  func testNewTabStaysPinnedWhileScrollingAndCreatesSelectedTab() async throws {
    let terminal = mainTerminal
    terminal.click()
    await requireInitialSidebarTab()
    let tabCount = 25

    for _ in 1..<tabCount {
      app.typeKey("t", modifierFlags: .command)
    }

    let didCreateTabs = await waitForSidebarElementCount(
      sidebarTabRows,
      equals: tabCount,
      timeout: .seconds(30)
    )
    XCTAssertTrue(didCreateTabs)

    let outline = try require(sidebarTabOutline)
    for _ in 0..<3 {
      outline.swipeDown()
    }

    let firstTab = sidebarTabRows.firstMatch
    let didRevealFirstTab = await wait(for: firstTab) { $0.isHittable }
    XCTAssertTrue(didRevealFirstTab)

    let newTab = try require(
      sidebarPinnedControl(SupatermUITestIdentifier.Accessibility.sidebarNewTab)
    )
    let pinnedFrame = newTab.frame
    let lastTab = sidebarTabRows.element(boundBy: tabCount - 1)
    for _ in 0..<3 {
      outline.swipeUp()
    }

    let didScroll = await wait(for: lastTab) {
      $0.isHittable && !firstTab.isHittable
    }
    XCTAssertTrue(didScroll)

    let didKeepNewTabPinned = await wait(for: newTab) {
      $0.isHittable && abs($0.frame.minY - pinnedFrame.minY) < 2
    }
    XCTAssertTrue(didKeepNewTabPinned)

    newTab.click()

    let didCreatePinnedTab = await waitForSidebarElementCount(sidebarTabRows, equals: tabCount + 1)
    XCTAssertTrue(didCreatePinnedTab)
    let createdTab = sidebarTabRows.element(boundBy: tabCount)
    let didSelectCreatedTab = await wait(for: createdTab) { $0.isSelected }
    XCTAssertTrue(didSelectCreatedTab)
  }

  @MainActor
  func testSidebarResizePersistsAcrossRelaunch() async throws {
    await requireInitialSidebarTab()
    let handle = try require(sidebarResizeHandle)
    let originalWidth = sidebarWidth(for: handle)
    let start = handle.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))

    start.press(
      forDuration: 0.2,
      thenDragTo: start.withOffset(CGVector(dx: 48, dy: 0)),
      withVelocity: .slow,
      thenHoldForDuration: 0
    )

    let didResize = await wait(for: handle) {
      $0.isHittable && self.sidebarWidth(for: $0) > originalWidth + 24
    }
    XCTAssertTrue(didResize)
    let resizedWidth = sidebarWidth(for: handle)

    try relaunch()

    let restoredHandle = try require(sidebarResizeHandle, timeout: 30)
    let didRestoreWidth = await wait(for: restoredHandle, timeout: .seconds(30)) {
      $0.isHittable && abs(self.sidebarWidth(for: $0) - resizedWidth) < 3
    }
    XCTAssertTrue(didRestoreWidth)
  }

  @MainActor
  func testDraggingSidebarBelowMinimumCollapsesIt() async throws {
    await requireInitialSidebarTab()
    let handle = try require(sidebarResizeHandle)
    let window = mainWindow
    let destination = window.coordinate(withNormalizedOffset: CGVector(dx: 0.001, dy: 0.5))

    try drag(handle, to: destination)

    let didCollapse = await wait(for: sidebarTabRows.firstMatch) { !$0.isHittable }
    XCTAssertTrue(didCollapse)
  }

  @MainActor
  func testBlankHeaderDragsWindowWithoutBlockingSpaceSwitcher() async throws {
    await requireInitialSidebarTab()
    let window = mainWindow
    let spaceSwitcher = try require(displayedSpace)

    spaceSwitcher.click()
    let newSpace = try require(app.menuItems["New Space"])
    XCTAssertTrue(newSpace.isHittable)
    app.typeKey(.escape, modifierFlags: [])

    let initialFrame = window.frame
    let start = window.coordinate(
      withNormalizedOffset: headerDragOffset(window: window, spaceSwitcher: spaceSwitcher)
    )
    start.press(
      forDuration: 0.2,
      thenDragTo: start.withOffset(CGVector(dx: 60, dy: 40)),
      withVelocity: .slow,
      thenHoldForDuration: 0
    )

    let didMoveWindow = await wait(for: window) {
      abs($0.frame.minX - initialFrame.minX) > 10 || abs($0.frame.minY - initialFrame.minY) > 10
    }
    XCTAssertTrue(didMoveWindow)
  }

  @MainActor
  private func sidebarWidth(for handle: XCUIElement) -> CGFloat {
    handle.frame.midX - mainWindow.frame.minX
  }

  @MainActor
  private func headerDragOffset(
    window: XCUIElement,
    spaceSwitcher: XCUIElement
  ) -> CGVector {
    let frame = window.frame
    let sidebarTrailingEdge = sidebarTabRows.firstMatch.frame.maxX
    let x = min(sidebarTrailingEdge - 8, spaceSwitcher.frame.maxX + 12)
    return CGVector(
      dx: (x - frame.minX) / frame.width,
      dy: (spaceSwitcher.frame.midY - frame.minY) / frame.height
    )
  }
}
