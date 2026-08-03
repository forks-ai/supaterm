import XCTest

final class HoverLinkUITests: SupatermUITestCase {
  @MainActor
  func testHoveredLinkBannerMovesAwayFromPointer() async throws {
    _ = mainTerminal
    try clickMenuItem(.splitDown)
    let terminals = app.textViews
    let didSplit = await wait(for: terminals.firstMatch, timeout: .seconds(30)) {
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
      XCTAssertLessThanOrEqual(abs(leadingFrame.minX - terminal.frame.minX), 4)
      XCTAssertLessThanOrEqual(abs(leadingFrame.maxY - terminal.frame.maxY), 4)

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
      XCTAssertLessThanOrEqual(abs(banner.frame.maxX - terminal.frame.maxX), 4)
    }
  }
}
