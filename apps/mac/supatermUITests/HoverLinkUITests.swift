import XCTest

final class HoverLinkUITests: SupatermUITestCase {
  @MainActor
  func testHoveredLinkBannerMovesAwayFromPointer() async throws {
    _ = mainTerminal
    try clickMenuItem(.splitDown)
    let terminals = app.textViews
    let didSplit = await wait(for: terminals.firstMatch, timeout: .seconds(30)) { _ in
      terminals.count == 2
    }
    XCTAssertTrue(didSplit)
    let terminal = try XCTUnwrap(
      terminals.allElementsBoundByIndex.min { $0.frame.midY < $1.frame.midY }
    )
    terminal.click()

    let link = "https://supaterm.com/docs/terminal/hovered-link-feedback-for-split-pane-regression"
    app.typeText("clear; printf '\\033[H\(link)\\033[999B\\033[A\(link)'; sleep 300")
    app.typeKey(.return, modifierFlags: [])
    let linkAppeared = await wait(for: terminal, timeout: .seconds(30)) {
      ($0.value as? String)?.contains(link) == true
    }
    XCTAssertTrue(linkAppeared)

    let banner = element(SupatermUITestIdentifier.Accessibility.hoveredLink)
    XCUIElement.perform(withKeyModifiers: .command) {
      terminal.coordinate(withNormalizedOffset: .zero)
        .withOffset(
          CGVector(
            dx: terminal.frame.width * 0.6,
            dy: 12
          )
        )
        .hover()

      guard banner.waitForExistence(timeout: 10) else {
        XCTFail("Hovered link banner did not appear")
        return
      }
      XCTAssertEqual(banner.label, "Hovered link: \(link)")

      let leadingFrame = banner.frame
      XCTAssertEqual(leadingFrame.minX - terminal.frame.minX, 8, accuracy: 4)
      XCTAssertEqual(terminal.frame.maxY - leadingFrame.maxY, 8, accuracy: 4)

      terminal.coordinate(withNormalizedOffset: .zero)
        .withOffset(
          CGVector(
            dx: leadingFrame.midX - terminal.frame.minX,
            dy: leadingFrame.minY - terminal.frame.minY + 6
          )
        )
        .hover()
      let movedToTrailingEdge =
        XCTWaiter.wait(
          for: [
            XCTNSPredicateExpectation(
              predicate: NSPredicate { _, _ in
                banner.exists && banner.frame.minX > leadingFrame.minX + 20
              },
              object: banner
            )
          ],
          timeout: 10
        ) == .completed
      XCTAssertTrue(movedToTrailingEdge)
      XCTAssertEqual(terminal.frame.maxX - banner.frame.maxX, 8, accuracy: 4)
    }
  }
}
