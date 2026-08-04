import XCTest

final class PaneZoomUITests: SupatermUITestCase {
  @MainActor
  func testToggleSplitZoomFocusesTargetPane() async throws {
    _ = try await requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try await requireVisiblePanes(count: 2)
    let leftPane = try XCTUnwrap(panes.min { $0.frame.midX < $1.frame.midX })
    let paneIdentifiers = Set(panes.map(\.identifier))

    try clickMenuItem(.selectSplitLeft)
    try await requireFocus(on: leftPane)

    try clickMenuItem(.zoomSplit)
    let zoomedPanes = try await requireVisiblePanes(count: 1)
    XCTAssertEqual(zoomedPanes[0].identifier, leftPane.identifier)
    try await requireFocus(on: leftPane)

    try clickMenuItem(.zoomSplit)
    let restoredPanes = try await requireVisiblePanes(count: 2)
    XCTAssertEqual(Set(restoredPanes.map(\.identifier)), paneIdentifiers)
    try await requireFocus(on: leftPane)
  }

  @MainActor
  func testZoomSplitHidesAndRestoresOtherPane() async throws {
    _ = try await requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try await requireVisiblePanes(count: 2)
    let paneIdentifiers = Set(panes.map(\.identifier))

    try clickMenuItem(.zoomSplit)

    let zoomedPanes = try await requireVisiblePanes(count: 1)
    XCTAssertTrue(paneIdentifiers.contains(zoomedPanes[0].identifier))

    try clickMenuItem(.zoomSplit)

    let restoredPanes = try await requireVisiblePanes(count: 2)
    XCTAssertEqual(Set(restoredPanes.map(\.identifier)), paneIdentifiers)
  }
}
