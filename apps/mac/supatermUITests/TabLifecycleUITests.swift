import XCTest

final class TabLifecycleUITests: SupatermUITestCase {
  @MainActor
  func testNewAndCloseTabUpdateSidebarRows() async throws {
    await requireInitialSidebarTab()

    try clickMenuItem(.newTab)

    let didCreateTab = await waitForSidebarElementCount(
      sidebarTabRows,
      equals: 2,
      timeout: .seconds(30)
    )
    XCTAssertTrue(didCreateTab)

    try closeSelectedTab()

    let didCloseTab = await waitForSidebarElementCount(
      sidebarTabRows,
      equals: 1,
      timeout: .seconds(30)
    )
    XCTAssertTrue(didCloseTab)
  }

  @MainActor
  func testChangingTabTitleUpdatesSidebarRow() async throws {
    await requireInitialSidebarTab()

    let title = "Renamed UI Tab"
    try await renameSelectedTab(to: title)

    XCTAssertTrue(sidebarTabRow(named: title).exists)
  }

  @MainActor
  func testPinAndUnpinMoveTabBetweenSidebarSections() async throws {
    await requireInitialSidebarTab()

    let title = "Lane UI Tab"
    try await renameSelectedTab(to: title)

    let row = sidebarTabRow(named: title)
    let didShowRegularTab = await wait(for: row) {
      $0.exists && !$0.label.contains("Pinned")
    }
    XCTAssertTrue(didShowRegularTab)

    try clickSidebarContextMenuItem("Pin Tab", on: row)

    let didMoveToPinned = await wait(for: row) {
      $0.label.contains("Pinned")
    }
    XCTAssertTrue(didMoveToPinned)

    try clickSidebarContextMenuItem("Unpin Tab", on: row)

    let didMoveToRegular = await wait(for: row) {
      $0.exists && !$0.label.contains("Pinned")
    }
    XCTAssertTrue(didMoveToRegular)
  }
}
