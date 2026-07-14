import XCTest

final class FoundationSmokeUITests: SupatermUITestCase {
  @MainActor
  func testFoundationStack() async throws {
    _ = mainWindow

    let tabRows = app.buttons.matching(
      identifier: SupatermUITestIdentifier.Accessibility.sidebarTabRow
    )
    guard tabRows.firstMatch.waitForExistence(timeout: 30) else {
      XCTFail("Initial sidebar tab row did not appear")
      return
    }

    try clickMenuItem(.newTab)

    let didCreateSecondTab = await wait(
      for: tabRows.element(boundBy: 1),
      timeout: .seconds(30)
    ) { $0.exists }
    guard didCreateSecondTab else {
      XCTFail("Second sidebar tab row did not appear")
      return
    }
    guard tabRows.count == 2 else {
      XCTFail("Expected two sidebar tab rows")
      return
    }

    try clickMenuItem(.openCommandPalette)

    let paletteInput = app.textFields[
      SupatermUITestIdentifier.Accessibility.paletteInput
    ]
    guard paletteInput.waitForExistence(timeout: 10) else {
      XCTFail("Command palette input did not appear")
      return
    }

    app.typeKey(.escape, modifierFlags: [])

    let didDismissPalette = await wait(for: paletteInput) { !$0.exists }
    XCTAssertTrue(didDismissPalette)
  }
}
