import Foundation
import XCTest

final class PaneContextMenuUITests: SupatermUITestCase {
  @MainActor
  func testContextMenuClosesClickedPaneWhenSessionPersistenceIsDisabled() async throws {
    try await assertContextMenuClosesClickedPane(zmxSessionsEnabled: false)
  }

  @MainActor
  func testContextMenuClosesClickedPaneWhenSessionPersistenceIsEnabled() async throws {
    try await assertContextMenuClosesClickedPane(zmxSessionsEnabled: true)
  }

  @MainActor
  private func assertContextMenuClosesClickedPane(zmxSessionsEnabled: Bool) async throws {
    try relaunchWithoutCloseConfirmation(zmxSessionsEnabled: zmxSessionsEnabled)
    _ = try await requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try await requireVisiblePanes(count: 2)
    let leftPane = try XCTUnwrap(panes.min { $0.frame.midX < $1.frame.midX })
    let rightPane = try XCTUnwrap(panes.max { $0.frame.midX < $1.frame.midX })

    rightPane.click()
    try await requireFocus(on: rightPane)
    let marker = "close-pane-ready-\(UUID().uuidString.prefix(8))"
    rightPane.typeText("echo \(marker)\n")
    let shellIsReady = await wait(for: rightPane, timeout: .seconds(30)) {
      ($0.value as? String)?.contains(marker) == true
    }
    XCTAssertTrue(shellIsReady)

    leftPane.click()
    try await requireFocus(on: leftPane)
    rightPane.rightClick()
    let closePane = app.menuItems["Close Pane"].firstMatch
    try require(closePane)
    closePane.click()

    let survivors = try await requireVisiblePanes(count: 1)
    XCTAssertEqual(survivors[0].identifier, leftPane.identifier)
  }
}
