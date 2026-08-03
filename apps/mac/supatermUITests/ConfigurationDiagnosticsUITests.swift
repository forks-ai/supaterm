import Foundation
import XCTest

final class ConfigurationDiagnosticsUITests: SupatermUITestCase {
  @MainActor
  func testEscapeIgnoresConfigurationErrors() throws {
    let diagnosticsWindow = try showConfigurationErrors()

    app.typeKey(.escape, modifierFlags: [])

    XCTAssertTrue(diagnosticsWindow.waitForNonExistence(timeout: 10))
  }

  @MainActor
  func testReturnReloadsConfiguration() throws {
    let diagnosticsWindow = try showConfigurationErrors()
    try Data("background = #101010\n".utf8).write(to: configURL)

    app.typeKey(.return, modifierFlags: [])

    XCTAssertTrue(diagnosticsWindow.waitForNonExistence(timeout: 10))
  }

  @MainActor
  private func showConfigurationErrors() throws -> XCUIElement {
    try FileManager.default.createDirectory(
      at: configURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data("definitely-invalid-key = nope\n".utf8).write(to: configURL)
    app.launchEnvironment["XDG_CONFIG_HOME"] = stateHome.path
    try relaunch()

    let diagnosticsWindow = try require(app.windows["Configuration Errors"], timeout: 30)
    diagnosticsWindow.click()
    return diagnosticsWindow
  }

  @MainActor
  private var configURL: URL {
    stateHome
      .appendingPathComponent("ghostty", isDirectory: true)
      .appendingPathComponent("config", isDirectory: false)
  }
}
