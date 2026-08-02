import XCTest

final class TabGroupingDragUITests: SupatermUITestCase {
  @MainActor
  func testGroupCloseAppearsOnlyWhileHoveringItsHeader() throws {
    try createNamedTabs(["Seed"])
    try createGroup(named: "Hover", containing: "Seed")
    let header = try require(sidebarGroupHeader(named: "Hover"))
    let child = try require(sidebarStructuralTabRow(named: "Seed"))
    let close = app.buttons["Close Hover"]
    XCTAssertEqual(header.elementType, .button)

    header.hover()
    XCTAssertTrue(close.waitForExistence(timeout: 2))

    child.hover()
    let didHideClose = wait(for: close) { !$0.exists }
    XCTAssertTrue(didHideClose)
  }

  @MainActor
  func testGroupHeaderTogglesFromItsFullWidth() throws {
    try createNamedTabs(["Seed"])
    try createGroup(named: "Toggle", containing: "Seed")
    let header = try require(sidebarGroupHeader(named: "Toggle"))
    let row = try require(sidebarGroupHeaders.matching(identifier: header.identifier).firstMatch)
    XCTAssertEqual(header.frame, row.frame)

    header.click()
    let didCollapse = wait(for: sidebarStructuralTabRow(named: "Seed")) { !$0.exists }
    XCTAssertTrue(didCollapse)

    header.click()
    XCTAssertTrue(sidebarStructuralTabRow(named: "Seed").waitForExistence(timeout: 2))
  }

  @MainActor
  func testNewTabCommandsChooseRootOrSelectedGroup() throws {
    try createNamedTabs(["Seed"])
    try createGroup(named: "Target", containing: "Seed")
    let seed = try require(sidebarTabRow(named: "Seed"))

    seed.click()
    app.typeKey("t", modifierFlags: .command)
    let didCreateRootTab = waitForSidebarElementCount(sidebarTabRows, equals: 2)
    XCTAssertTrue(didCreateRootTab)
    try renameSelectedTab(to: "Root")
    requireSidebarStructure([
      .group("Target", children: ["Seed"]),
      .tab("Root"),
    ])

    seed.click()
    app.typeKey("t", modifierFlags: [.command, .option])
    let didCreateShortcutChild = waitForSidebarElementCount(sidebarTabRows, equals: 3)
    XCTAssertTrue(didCreateShortcutChild)
    try renameSelectedTab(to: "Shortcut Child")
    requireSidebarStructure([
      .group("Target", children: ["Seed", "Shortcut Child"]),
      .tab("Root"),
    ])

    try clickSidebarContextMenuItem(
      "New Tab in Group",
      on: sidebarGroupHeader(named: "Target")
    )
    let didCreateMenuChild = waitForSidebarElementCount(sidebarTabRows, equals: 4)
    XCTAssertTrue(didCreateMenuChild)
    try renameSelectedTab(to: "Menu Child")
    requireSidebarStructure([
      .group("Target", children: ["Seed", "Shortcut Child", "Menu Child"]),
      .tab("Root"),
    ])
  }

  @MainActor
  func testDroppingTabOnTabOnlyReordersRoots() throws {
    try createNamedTabs(["First", "Mover"])

    try drag(
      sidebarStructuralTabRow(named: "Mover"),
      to: sidebarStructuralTabRow(named: "First")
    )

    requireSidebarStructure([
      .tab("Mover"),
      .tab("First"),
    ])
    XCTAssertEqual(sidebarGroupHeaders.count, 0)
  }

  @MainActor
  func testRootTabDropsBeforeFirstGroupAtLeadingEdge() throws {
    try createNamedTabs(["Group Seed", "Mover"])
    try createGroup(named: "First", containing: "Group Seed")
    requireSidebarStructure([
      .group("First", children: ["Group Seed"]),
      .tab("Mover"),
    ])

    try drag(
      sidebarStructuralTabRow(named: "Mover"),
      to: sidebarGroupHeader(named: "First"),
      destinationOffset: CGVector(dx: 0.5, dy: 0.2)
    )

    requireSidebarStructure([
      .tab("Mover"),
      .group("First", children: ["Group Seed"]),
    ])
  }

  @MainActor
  func testRootTabDropsIntoExpandedGroup() throws {
    try createNamedTabs(["Group Seed", "Root A", "Root B"])
    try createGroup(named: "Alpha", containing: "Group Seed")
    requireSidebarStructure([
      .group("Alpha", children: ["Group Seed"]),
      .tab("Root A"),
      .tab("Root B"),
    ])

    try drag(
      sidebarStructuralTabRow(named: "Root A"),
      to: sidebarGroupHeader(named: "Alpha")
    )

    requireSidebarStructure([
      .group("Alpha", children: ["Group Seed", "Root A"]),
      .tab("Root B"),
    ])
  }

  @MainActor
  func testLastGroupChildDropsIntoRootAndRemovesEmptyGroup() throws {
    try createNamedTabs(["Root Before", "Only Child", "Root After"])
    try createGroup(named: "Solo", containing: "Only Child")
    requireSidebarStructure([
      .tab("Root Before"),
      .group("Solo", children: ["Only Child"]),
      .tab("Root After"),
    ])

    try drag(
      sidebarStructuralTabRow(named: "Only Child"),
      to: sidebarFooterRow(SupatermUITestIdentifier.Accessibility.sidebarNewTab)
    )

    requireSidebarStructure([
      .tab("Root Before"),
      .tab("Root After"),
      .tab("Only Child"),
    ])
    XCTAssertEqual(sidebarGroupHeaders.count, 0)
  }

  @MainActor
  func testWholeGroupAtBottomDropsAtSecondRootPosition() throws {
    try createNamedTabs(["First", "Second", "Third", "Group Child"])
    try createGroup(named: "Bottom Group", containing: "Group Child")
    requireSidebarStructure([
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

    requireSidebarStructure([
      .tab("First"),
      .group("Bottom Group", children: ["Group Child"]),
      .tab("Second"),
      .tab("Third"),
    ])
  }

  @MainActor
  func testGroupedTabDroppedBetweenGroupsRemainsRoot() throws {
    try createNamedTabs(["Alpha Child", "Beta Child", "Mover"])
    try createGroup(named: "Alpha", containing: "Alpha Child")
    try createGroup(named: "Beta", containing: "Beta Child")

    try drag(
      sidebarStructuralTabRow(named: "Mover"),
      to: sidebarGroupHeader(named: "Beta")
    )
    requireSidebarStructure([
      .group("Alpha", children: ["Alpha Child"]),
      .group("Beta", children: ["Beta Child", "Mover"]),
    ])

    let alphaChild = try require(sidebarStructuralTabRow(named: "Alpha Child"))
    let betaHeader = try require(sidebarGroupHeader(named: "Beta"))
    let gap = max(1, betaHeader.frame.minY - alphaChild.frame.maxY)
    let destination = betaHeader.coordinate(
      withNormalizedOffset: CGVector(dx: 0.5, dy: 0)
    ).withOffset(CGVector(dx: 0, dy: -gap / 2))
    try drag(sidebarStructuralTabRow(named: "Mover"), to: destination)

    requireSidebarStructure([
      .group("Alpha", children: ["Alpha Child"]),
      .tab("Mover"),
      .group("Beta", children: ["Beta Child"]),
    ])
  }

  @MainActor
  func testExpandedAndCollapsedGroupHeadersAcceptTabs() throws {
    try createNamedTabs(["Seed", "Expanded Join", "Collapsed Join", "Tail"])
    try createGroup(named: "Target", containing: "Seed")

    try drag(
      sidebarStructuralTabRow(named: "Expanded Join"),
      to: sidebarGroupHeader(named: "Target")
    )
    requireSidebarStructure([
      .group("Target", children: ["Seed", "Expanded Join"]),
      .tab("Collapsed Join"),
      .tab("Tail"),
    ])

    let tail = try require(sidebarTabRow(named: "Tail"))
    tail.click()
    let didSelectTail = waitForSidebarSelection(tail)
    XCTAssertTrue(didSelectTail)
    try clickSidebarContextMenuItem("Collapse Group", on: sidebarGroupHeader(named: "Target"))
    let didCollapse = wait(for: sidebarGroupHeader(named: "Target")) {
      ($0.value as? String) == "Collapsed"
    }
    XCTAssertTrue(didCollapse)
    XCTAssertFalse(sidebarStructuralTabRow(named: "Seed").exists)

    try drag(
      sidebarStructuralTabRow(named: "Collapsed Join"),
      to: sidebarGroupHeader(named: "Target"),
      destinationOffset: CGVector(dx: 0.5, dy: 0.35)
    )
    let didAddAndExpandCollapsedGroup = wait(
      for: sidebarGroupHeader(named: "Target")
    ) {
      $0.label.contains("3 tabs") && ($0.value as? String) == "Expanded"
    }
    XCTAssertTrue(didAddAndExpandCollapsedGroup)

    requireSidebarStructure([
      .group("Target", children: ["Seed", "Expanded Join", "Collapsed Join"]),
      .tab("Tail"),
    ])
  }

  @MainActor
  func testNewTabFooterDropAppendsRootWithoutActivatingFooter() throws {
    try createNamedTabs(["First", "Second", "Third"])
    let newTab = try require(
      sidebarFooterRow(SupatermUITestIdentifier.Accessibility.sidebarNewTab)
    )

    try drag(sidebarStructuralTabRow(named: "First"), to: newTab)

    requireSidebarStructure([
      .tab("Second"),
      .tab("Third"),
      .tab("First"),
    ])
    XCTAssertEqual(sidebarGroupHeaders.count, 0)
  }

  @MainActor
  private func requireSidebarStructure(
    _ expected: [SidebarRootExpectation],
    file: StaticString = #filePath,
    line: UInt = #line
  ) {
    let didMatch = waitForSidebarStructure(expected)
    XCTAssertTrue(
      didMatch,
      "Expected \(expected); actual \(sidebarStructureDescription())",
      file: file,
      line: line
    )
  }
}
