import AppKit
import XCTest

final class SearchPasteUITests: SupatermUITestCase {
  @MainActor
  func testUserCanPasteIntoSearchAfterReactivatingApp() throws {
    preservePasteboards()

    let terminal = mainTerminal
    terminal.click()

    let readinessText = "search focus ready"
    let terminalText = try XCTUnwrap(terminal.value as? String)
    app.typeKey("f", modifierFlags: .command)

    let searchField = app.textFields[SupatermUITestIdentifier.Accessibility.searchField]
    let focusedSearchField = app.textFields
      .matching(identifier: SupatermUITestIdentifier.Accessibility.searchField)
      .matching(NSPredicate(format: "hasKeyboardFocus == true"))
      .firstMatch
    XCTAssertTrue(focusedSearchField.waitForExistence(timeout: 10))
    searchField.typeText(readinessText)
    XCTAssertEqual(terminal.value as? String, terminalText)
    replacePasteboard(with: "readiness sentinel")
    app.typeKey("a", modifierFlags: .command)
    app.typeKey("c", modifierFlags: .command)
    XCTAssertEqual(NSPasteboard.general.string(forType: .string), readinessText)
    app.typeKey(.delete, modifierFlags: [])

    let pastedText = "search paste regression"
    replacePasteboard(with: pastedText)

    reactivate(app)
    XCTAssertTrue(focusedSearchField.waitForExistence(timeout: 10))

    app.typeKey("v", modifierFlags: .command)
    let didPaste = wait(for: searchField) { $0.value as? String == pastedText }
    XCTAssertTrue(didPaste)
    XCTAssertEqual(terminal.value as? String, terminalText)

    replacePasteboard(with: "verification sentinel")
    app.typeKey("a", modifierFlags: .command)
    app.typeKey("c", modifierFlags: .command)

    XCTAssertEqual(NSPasteboard.general.string(forType: .string), pastedText)

    app.typeKey(.escape, modifierFlags: [])
    reactivate(app)

    let focusedTerminal = app.textViews
      .matching(NSPredicate(format: "hasKeyboardFocus == true"))
      .firstMatch
    XCTAssertTrue(focusedTerminal.waitForExistence(timeout: 10))

    let terminalInput = "terminal focus restored"
    focusedTerminal.typeText(terminalInput)
    let didTypeInTerminal = wait(for: terminal) {
      $0.value as? String == terminalText + terminalInput
    }
    XCTAssertTrue(didTypeInTerminal)
  }

  @MainActor
  private func reactivate(_ app: XCUIApplication) {
    let finder = XCUIApplication(bundleIdentifier: "com.apple.finder")
    finder.activate()
    XCTAssertTrue(finder.wait(for: .runningForeground, timeout: 5))
    app.activate()
    XCTAssertTrue(app.wait(for: .runningForeground, timeout: 5))
  }

}
