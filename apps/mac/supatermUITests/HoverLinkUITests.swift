import XCTest

final class HoverLinkUITests: SupatermUITestCase {
  @MainActor
  func testHoveredLinkBannerMovesAwayFromPointer() async throws {
    let terminal = mainTerminal
    terminal.click()

    let link = "https://supaterm.com/docs/hover-link"
    app.typeText("clear; printf '\(link)\\n'")
    app.typeKey(.return, modifierFlags: [])
    let linkAppeared = await wait(for: terminal, timeout: .seconds(30)) {
      ($0.value as? String)?.contains(link) == true
    }
    XCTAssertTrue(linkAppeared)

    terminal.coordinate(withNormalizedOffset: .zero)
      .withOffset(CGVector(dx: 48, dy: 12))
      .hover()

    let banner = element(SupatermUITestIdentifier.Accessibility.hoveredLink)
    try require(banner)
    XCTAssertEqual(banner.label, "Hovered link")
    XCTAssertEqual(banner.value as? String, link)

    let leadingFrame = banner.frame
    XCTAssertLessThanOrEqual(abs(leadingFrame.minX - terminal.frame.minX), 4)
    XCTAssertLessThanOrEqual(abs(leadingFrame.maxY - terminal.frame.maxY), 4)

    banner.hover()
    let movedToTrailingEdge = await wait(for: banner) {
      $0.exists && $0.frame.minX > leadingFrame.minX + 20
    }
    XCTAssertTrue(movedToTrailingEdge)
    XCTAssertLessThanOrEqual(abs(banner.frame.maxX - terminal.frame.maxX), 4)
  }
}
