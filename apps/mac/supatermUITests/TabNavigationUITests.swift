import XCTest

final class TabNavigationUITests: SupatermUITestCase {
  @MainActor
  func testTabNavigationUpdatesSelectedSidebarRow() async throws {
    try await createNamedTabs(["First UI Tab", "Second UI Tab", "Third UI Tab"])

    let firstTab = sidebarTabRow(named: "First UI Tab")
    let secondTab = sidebarTabRow(named: "Second UI Tab")
    let thirdTab = sidebarTabRow(named: "Third UI Tab")
    XCTAssertTrue(thirdTab.isSelected)

    try clickMenuItem(.nextTab)

    let didSelectFirstTab = await waitForSidebarSelection(firstTab)
    XCTAssertTrue(didSelectFirstTab)

    try clickMenuItem(.selectLastTab)

    let didSelectLastTab = await waitForSidebarSelection(thirdTab)
    XCTAssertTrue(didSelectLastTab)

    try clickMenuItem(.previousTab)

    let didSelectPreviousTab = await waitForSidebarSelection(secondTab)
    XCTAssertTrue(didSelectPreviousTab)
  }

  @MainActor
  func testNewTabAppendsAtEndWhenMiddleTabSelected() async throws {
    try await createNamedTabs(["First UI Tab", "Second UI Tab", "Third UI Tab"])

    let secondTab = sidebarTabRow(named: "Second UI Tab")
    try clickMenuItem(.previousTab)
    let didSelectSecondTab = await waitForSidebarSelection(secondTab)
    XCTAssertTrue(didSelectSecondTab)

    try clickMenuItem(.newTab)
    let didCreateFourthTab = await waitForSidebarElementCount(
      sidebarTabRows,
      equals: 4,
      timeout: .seconds(30)
    )
    XCTAssertTrue(didCreateFourthTab)
    try await renameSelectedTab(to: "Fourth UI Tab")

    let expectedOrder = ["First UI Tab", "Second UI Tab", "Third UI Tab", "Fourth UI Tab"]
    let didAppendAtEnd = await waitForTabOrder(expectedOrder)
    XCTAssertTrue(didAppendAtEnd)
    XCTAssertTrue(sidebarTabRow(named: "Fourth UI Tab").isSelected)
  }
}
