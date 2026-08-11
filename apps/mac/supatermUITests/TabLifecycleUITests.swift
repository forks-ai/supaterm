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
}
