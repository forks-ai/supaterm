import XCTest

final class HoverLinkUITests: SupatermUITestCase {
  @MainActor
  func testHoveredLinkBannerMovesAwayFromPointer() async throws {
    let terminal = mainTerminal
    terminal.click()

    let link = "https://supaterm.com/docs/terminal/hovered-link-feedback-for-split-pane-regression"
    app.typeText("clear; printf '\\033[999B\(link)'; sleep 300")
    app.typeKey(.return, modifierFlags: [])
    let linkAppeared = await wait(for: terminal, timeout: .seconds(30)) {
      ($0.value as? String)?.contains(link) == true
    }
    XCTAssertTrue(linkAppeared)

    XCUIElement.perform(withKeyModifiers: .command) {
      terminal.coordinate(withNormalizedOffset: .zero)
        .withOffset(
          CGVector(
            dx: terminal.frame.width * 0.6,
            dy: terminal.frame.height - 12
          )
        )
        .hover()
    }

    let banner = element(SupatermUITestIdentifier.Accessibility.hoveredLink)
    try require(banner)
    XCTAssertEqual(banner.label, "Hovered link")
    XCTAssertEqual(banner.value as? String, link)

    let leadingFrame = banner.frame
    XCTAssertLessThanOrEqual(abs(leadingFrame.minX - terminal.frame.minX), 4)
    XCTAssertLessThanOrEqual(abs(leadingFrame.maxY - terminal.frame.maxY), 4)

    XCUIElement.perform(withKeyModifiers: .command) {
      banner.hover()
    }
    let movedToTrailingEdge = await wait(for: banner) {
      $0.exists && $0.frame.minX > leadingFrame.minX + 20
    }
    XCTAssertTrue(movedToTrailingEdge)
    XCTAssertLessThanOrEqual(abs(banner.frame.maxX - terminal.frame.maxX), 4)
  }
}
