import Foundation
import XCTest

extension SupatermUITestCase {
  @MainActor
  var terminalPanes: XCUIElementQuery {
    app.textViews.matching(
      NSPredicate(
        format: "identifier BEGINSWITH %@",
        SupatermUITestIdentifier.Accessibility.terminalPanePrefix
      )
    )
  }

  @MainActor
  fileprivate var focusedTerminalPanes: XCUIElementQuery {
    terminalPanes.matching(NSPredicate(format: "hasKeyboardFocus == true"))
  }

  @MainActor
  func focusedTerminalPane(identifier: String) -> XCUIElement {
    focusedTerminalPanes.matching(identifier: identifier).firstMatch
  }

  @MainActor
  func requireVisiblePanes(count expectedCount: Int) async throws -> [XCUIElement] {
    let didReachCount = await wait(for: mainWindow, timeout: .seconds(30)) { _ in
      guard self.terminalPanes.count == expectedCount else { return false }
      return (0..<expectedCount).allSatisfy {
        let pane = self.terminalPanes.element(boundBy: $0)
        return pane.exists && !pane.frame.isEmpty
      }
    }
    return try XCTUnwrap(
      didReachCount
        ? (0..<expectedCount).map { terminalPanes.element(boundBy: $0) }
        : nil,
      "Expected \(expectedCount) visible terminal panes"
    )
  }

  @MainActor
  func requireFocus(on pane: XCUIElement) async throws {
    let focusedPane = focusedTerminalPane(identifier: pane.identifier)
    let didFocus = await wait(for: focusedPane) { $0.exists }
    XCTAssertTrue(didFocus, "Expected pane \(pane.identifier) to have keyboard focus")
  }

  @MainActor
  func relaunchWithoutCloseConfirmation() throws {
    let ghosttyConfigDirectory = stateHome.appendingPathComponent("ghostty", isDirectory: true)
    try FileManager.default.createDirectory(
      at: ghosttyConfigDirectory,
      withIntermediateDirectories: true
    )
    try Data("confirm-close-surface = false\n".utf8).write(
      to: ghosttyConfigDirectory.appendingPathComponent("config")
    )
    app.launchEnvironment["XDG_CONFIG_HOME"] = stateHome.path
    try relaunch()
  }
}
