import XCTest

final class PanesSplitsUITests: SupatermUITestCase {
  @MainActor
  func testSplitRightCreatesTwoVisiblePanes() async throws {
    _ = try await requireVisiblePanes(count: 1)

    try clickMenuItem(.splitRight)

    let panes = try await requireVisiblePanes(count: 2)
    XCTAssertGreaterThan(
      abs(panes[0].frame.midX - panes[1].frame.midX),
      abs(panes[0].frame.midY - panes[1].frame.midY)
    )
  }

  @MainActor
  func testSplitDownCreatesTwoVisiblePanes() async throws {
    _ = try await requireVisiblePanes(count: 1)

    try clickMenuItem(.splitDown)

    let panes = try await requireVisiblePanes(count: 2)
    XCTAssertGreaterThan(
      abs(panes[0].frame.midY - panes[1].frame.midY),
      abs(panes[0].frame.midX - panes[1].frame.midX)
    )
  }

  @MainActor
  func testDirectionalFocusNavigationMovesFocusBetweenPanes() async throws {
    _ = try await requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try await requireVisiblePanes(count: 2)
    let leftPane = try XCTUnwrap(panes.min { $0.frame.midX < $1.frame.midX })
    let rightPane = try XCTUnwrap(panes.max { $0.frame.midX < $1.frame.midX })

    try clickMenuItem(.selectSplitLeft)
    try await requireFocus(on: leftPane)

    try clickMenuItem(.selectSplitRight)
    try await requireFocus(on: rightPane)
  }

  @MainActor
  func testResizeAndEqualizeChangeLayoutWithoutLosingPanes() async throws {
    _ = try await requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try await requireVisiblePanes(count: 2)
    let leftPane = try XCTUnwrap(panes.min { $0.frame.midX < $1.frame.midX })
    let initialFrame = leftPane.frame
    let paneIdentifiers = Set(panes.map(\.identifier))

    for _ in 0..<3 {
      try clickMenuItem(.moveSplitDividerLeft)
    }

    let didResize = await wait(for: leftPane) {
      $0.exists && $0.frame.width < initialFrame.width - 5
    }
    guard didResize else {
      XCTFail("Split divider did not move left")
      return
    }
    let resizedPanes = try await requireVisiblePanes(count: 2)
    XCTAssertEqual(Set(resizedPanes.map(\.identifier)), paneIdentifiers)

    try clickMenuItem(.equalizeSplits)

    let didEqualize = await wait(for: leftPane) {
      $0.exists && abs($0.frame.width - initialFrame.width) < 2
    }
    XCTAssertTrue(didEqualize)
    let equalizedPanes = try await requireVisiblePanes(count: 2)
    XCTAssertEqual(Set(equalizedPanes.map(\.identifier)), paneIdentifiers)
  }

  @MainActor
  func testSplitWhileSearchOpenFocusesNewPane() async throws {
    let originalPane = try await requireVisiblePanes(count: 1)[0]
    originalPane.click()
    let originalIdentifier = originalPane.identifier

    app.typeKey("f", modifierFlags: .command)
    let searchField = app.textFields[SupatermUITestIdentifier.Accessibility.searchField]
    XCTAssertTrue(searchField.waitForExistence(timeout: 10))
    searchField.typeText("SPLITFOCUSNEEDLE")
    XCTAssertEqual(searchField.value as? String, "SPLITFOCUSNEEDLE")

    try clickMenuItem(.splitRight)
    let panes = try await requireVisiblePanes(count: 2)
    let newPane = try XCTUnwrap(panes.first { $0.identifier != originalIdentifier })

    let remountedSearchField = app.textFields[
      SupatermUITestIdentifier.Accessibility.searchField
    ]
    XCTAssertTrue(remountedSearchField.waitForExistence(timeout: 10))
    try await requireFocus(on: newPane)

    app.typeText(
      "printf '\\x53\\x50\\x4C\\x49\\x54\\x46\\x4F\\x43\\x55\\x53\\x4D\\x41\\x52\\x4B\\x45\\x52\\n'"
    )
    app.typeKey(.return, modifierFlags: [])
    let markerPrinted = await wait(for: newPane, timeout: .seconds(30)) {
      ($0.value as? String)?.contains("SPLITFOCUSMARKER") == true
    }
    XCTAssertTrue(markerPrinted)
    XCTAssertEqual(remountedSearchField.value as? String, "SPLITFOCUSNEEDLE")
  }
}
