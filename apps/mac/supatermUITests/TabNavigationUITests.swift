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

}
