import XCTest

final class FoundationSmokeUITests: SupatermUITestCase {
  @MainActor
  func testBundledSpCliIsOnPanePath() throws {
    let terminal = mainTerminal
    let didBecomeHittable = wait(for: terminal, timeout: 60) {
      $0.isHittable
    }
    XCTAssertTrue(didBecomeHittable)

    terminal.click()
    app.typeText("[ \"$(command -v sp)\" = \"$SUPATERM_CLI_PATH\" ] && echo SP-PATH-\"MATCHED\"\n")

    let matched = wait(for: terminal, timeout: 60) {
      ($0.value as? String)?.contains("SP-PATH-MATCHED") == true
    }
    XCTAssertTrue(matched, "bare sp did not resolve to $SUPATERM_CLI_PATH on pane PATH")
  }
}
