import XCTest

final class TabGroupingHeaderUITests: SupatermUITestCase {
  @MainActor
  func testGroupCloseAppearsOnlyWhileHoveringItsHeader() async throws {
    try await createNamedTabs(["Seed"])
    try await createGroup(named: "Hover", containing: "Seed")
    let header = try require(sidebarGroupHeader(named: "Hover"))
    let child = try require(sidebarStructuralTabRow(named: "Seed"))
    let close = app.buttons["Close Hover"]
    XCTAssertEqual(header.elementType, .button)

    header.hover()
    XCTAssertTrue(close.waitForExistence(timeout: 2))

    child.hover()
    let didHideClose = await wait(for: close) { !$0.exists }
    XCTAssertTrue(didHideClose)
  }

  @MainActor
  func testGroupHeaderTogglesFromItsFullWidth() async throws {
    try await createNamedTabs(["Seed"])
    try await createGroup(named: "Toggle", containing: "Seed")
    let header = try require(sidebarGroupHeader(named: "Toggle"))
    let row = try require(sidebarGroupHeaders.matching(identifier: header.identifier).firstMatch)
    XCTAssertEqual(header.frame, row.frame)

    header.click()
    let didCollapse = await wait(for: sidebarStructuralTabRow(named: "Seed")) { !$0.exists }
    XCTAssertTrue(didCollapse)

    header.click()
    XCTAssertTrue(sidebarStructuralTabRow(named: "Seed").waitForExistence(timeout: 2))
  }

  @MainActor
  func testCollapsedGroupSurvivesSidebarToggle() async throws {
    try await createNamedTabs(["Seed", "Root"])
    try await createGroup(named: "Toggle", containing: "Seed")
    let header = try require(sidebarGroupHeader(named: "Toggle"))

    header.click()
    let didCollapse = await wait(for: sidebarStructuralTabRow(named: "Seed")) { !$0.exists }
    XCTAssertTrue(didCollapse)

    let hideSidebarButton = app.buttons["Hide sidebar"]
    try require(hideSidebarButton)
    hideSidebarButton.click()
    let didCollapseSidebar = await waitForSidebarCollapsed()
    XCTAssertTrue(didCollapseSidebar)

    let showSidebarButton = app.buttons.matching(
      NSPredicate(format: "label BEGINSWITH %@", "Show sidebar")
    ).firstMatch
    try require(showSidebarButton)
    showSidebarButton.click()
    let didExpandSidebar = await waitForSidebarExpanded()
    XCTAssertTrue(didExpandSidebar)
    let restoredHeader = sidebarGroupHeader(named: "Toggle")
    let didRestore = await wait(for: restoredHeader) {
      $0.isHittable && ($0.value as? String) == "Collapsed"
    }
    XCTAssertTrue(didRestore)
    XCTAssertTrue(sidebarStructuralTabRow(named: "Root").isHittable)
    XCTAssertFalse(sidebarStructuralTabRow(named: "Seed").exists)
  }
}
