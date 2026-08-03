import XCTest

final class TabGroupBoundaryDragUITests: SupatermUITestCase {
  @MainActor
  func testLastGroupChildDropsIntoRootAndRemovesEmptyGroup() async throws {
    try await createNamedTabs(["Root Before", "Only Child", "Root After"])
    try await createGroup(named: "Solo", containing: "Only Child")
    await requireSidebarStructure([
      .tab("Root Before"),
      .group("Solo", children: ["Only Child"]),
      .tab("Root After"),
    ])

    try drag(
      sidebarStructuralTabRow(named: "Only Child"),
      to: sidebarFooterRow(SupatermUITestIdentifier.Accessibility.sidebarNewTab)
    )

    await requireSidebarStructure([
      .tab("Root Before"),
      .tab("Root After"),
      .tab("Only Child"),
    ])
    XCTAssertEqual(sidebarGroupHeaders.count, 0)
  }

  @MainActor
  func testWholeGroupAtBottomDropsAtSecondRootPosition() async throws {
    try await createNamedTabs(["First", "Second", "Third", "Group Child"])
    try await createGroup(named: "Bottom Group", containing: "Group Child")
    await requireSidebarStructure([
      .tab("First"),
      .tab("Second"),
      .tab("Third"),
      .group("Bottom Group", children: ["Group Child"]),
    ])

    try drag(
      sidebarGroupHeader(named: "Bottom Group"),
      to: sidebarStructuralTabRow(named: "Second"),
      destinationOffset: CGVector(dx: 0.5, dy: 0.1)
    )

    await requireSidebarStructure([
      .tab("First"),
      .group("Bottom Group", children: ["Group Child"]),
      .tab("Second"),
      .tab("Third"),
    ])
  }
}
