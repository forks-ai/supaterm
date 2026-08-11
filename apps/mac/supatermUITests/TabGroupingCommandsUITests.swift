import XCTest

final class TabGroupingCommandsUITests: SupatermUITestCase {
  @MainActor
  func testNewTabCommandsChooseRootOrSelectedGroup() async throws {
    try await createNamedTabs(["Seed"])
    try await createGroup(named: "Target", containing: "Seed")
    let seed = try require(sidebarTabRow(named: "Seed"))

    seed.click()
    app.typeKey("t", modifierFlags: .command)
    let didCreateRootTab = await waitForSidebarElementCount(sidebarTabRows, equals: 2)
    XCTAssertTrue(didCreateRootTab)
    try await renameSelectedTab(to: "Root")
    await requireSidebarStructure([
      .group("Target", children: ["Seed"]),
      .tab("Root"),
    ])

    seed.click()
    app.typeKey("t", modifierFlags: [.command, .option])
    let didCreateShortcutChild = await waitForSidebarElementCount(sidebarTabRows, equals: 3)
    XCTAssertTrue(didCreateShortcutChild)
    try await renameSelectedTab(to: "Shortcut Child")
    await requireSidebarStructure([
      .group("Target", children: ["Seed", "Shortcut Child"]),
      .tab("Root"),
    ])

    try clickSidebarContextMenuItem(
      "New Tab in Group",
      on: sidebarGroupHeader(named: "Target")
    )
    let didCreateMenuChild = await waitForSidebarElementCount(sidebarTabRows, equals: 4)
    XCTAssertTrue(didCreateMenuChild)
    try await renameSelectedTab(to: "Menu Child")
    await requireSidebarStructure([
      .group("Target", children: ["Seed", "Shortcut Child", "Menu Child"]),
      .tab("Root"),
    ])
  }
}
