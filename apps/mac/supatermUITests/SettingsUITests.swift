import Foundation
import XCTest

final class SettingsUITests: SupatermUITestCase {
  @MainActor
  func testCommandCommaOpensSettingsAndEveryTabShowsItsControls() throws {
    let settingsWindow = try openSettings()

    for tab in SettingsTab.allCases {
      XCTAssertTrue(element(tab.sidebarIdentifier, in: settingsWindow).waitForExistence(timeout: 10))
    }

    for tab in SettingsTab.allCases {
      let sidebarTab = element(tab.sidebarIdentifier, in: settingsWindow)
      sidebarTab.click()

      let keyControl = element(tab.keyControlIdentifier, in: settingsWindow)
      let didShowKeyControl = wait(for: keyControl) { $0.exists }
      XCTAssertTrue(didShowKeyControl, "\(tab.rawValue) did not show its key control")
    }
  }

  @MainActor
  func testRestoreTerminalLayoutPersistsAcrossRelaunch() throws {
    let settingsWindow = try openSettings()
    try select(.general, in: settingsWindow)

    let toggle = element(
      SupatermUITestIdentifier.Settings.restoreTerminalLayout,
      in: settingsWindow
    )
    let didLoadEnabledToggle = wait(for: toggle) { self.toggleState($0) == true }
    XCTAssertTrue(didLoadEnabledToggle)
    toggle.click()
    let didDisableToggle = wait(for: toggle) { self.toggleState($0) == false }
    XCTAssertTrue(didDisableToggle)
    let didPersistSetting = waitForSettingsFile(containing: "restore_layout = false")
    XCTAssertTrue(didPersistSetting)

    try relaunch()

    let relaunchedSettingsWindow = try openSettings()
    try select(.general, in: relaunchedSettingsWindow)
    let persistedToggle = element(
      SupatermUITestIdentifier.Settings.restoreTerminalLayout,
      in: relaunchedSettingsWindow
    )
    let didRestoreDisabledToggle = wait(for: persistedToggle) {
      self.toggleState($0) == false
    }
    XCTAssertTrue(didRestoreDisabledToggle)
  }

  @MainActor
  func testAppearanceModeSwitchesBetweenEveryOptionAndPersists() throws {
    let settingsWindow = try openSettings()
    try select(.general, in: settingsWindow)

    let light = element(SupatermUITestIdentifier.Settings.appearanceLight, in: settingsWindow)
    let dark = element(SupatermUITestIdentifier.Settings.appearanceDark, in: settingsWindow)
    let auto = element(SupatermUITestIdentifier.Settings.appearanceAuto, in: settingsWindow)
    for option in [light, dark, auto] {
      XCTAssertTrue(option.waitForExistence(timeout: 10))
    }

    light.click()
    let didSelectLight = waitForSelection(light)
    XCTAssertTrue(didSelectLight)
    dark.click()
    let didSelectDark = waitForSelection(dark)
    XCTAssertTrue(didSelectDark)
    auto.click()
    let didSelectAuto = waitForSelection(auto)
    XCTAssertTrue(didSelectAuto)
    let didPersistSetting = waitForSettingsFile(containing: "mode = \"system\"")
    XCTAssertTrue(didPersistSetting)

    try relaunch()

    let relaunchedSettingsWindow = try openSettings()
    try select(.general, in: relaunchedSettingsWindow)
    let persistedAuto = element(
      SupatermUITestIdentifier.Settings.appearanceAuto,
      in: relaunchedSettingsWindow
    )
    let didRestoreAuto = waitForSelection(persistedAuto)
    XCTAssertTrue(didRestoreAuto)
  }

  @MainActor
  func testAboutShowsVersionAndUpdateControls() throws {
    let settingsWindow = try openSettings()
    try select(.about, in: settingsWindow)

    let version = element(SupatermUITestIdentifier.Settings.aboutVersion, in: settingsWindow)
    XCTAssertTrue(version.waitForExistence(timeout: 10))
    let versionValue = version.value as? String
    XCTAssertFalse(versionValue?.isEmpty ?? true)
    XCTAssertNotEqual(versionValue, "Unknown Version")
    XCTAssertTrue(
      element(SupatermUITestIdentifier.Settings.checkForUpdates, in: settingsWindow)
        .waitForExistence(timeout: 10)
    )
    XCTAssertTrue(
      element(SupatermUITestIdentifier.Settings.updateChannel, in: settingsWindow)
        .waitForExistence(timeout: 10)
    )
    XCTAssertTrue(
      element(
        SupatermUITestIdentifier.Settings.automaticallyCheckForUpdates,
        in: settingsWindow
      )
      .waitForExistence(timeout: 10)
    )
  }

  @MainActor
  private func openSettings() throws -> XCUIElement {
    _ = mainWindow
    app.typeKey(",", modifierFlags: .command)

    let settingsWindow = app.windows.matching(
      identifier: SupatermUITestIdentifier.Settings.window
    ).firstMatch
    return try require(settingsWindow)
  }

  @MainActor
  private func select(
    _ tab: SettingsTab,
    in settingsWindow: XCUIElement
  ) throws {
    let sidebarTab = element(tab.sidebarIdentifier, in: settingsWindow)
    try require(sidebarTab)
    sidebarTab.click()

    let keyControl = element(tab.keyControlIdentifier, in: settingsWindow)
    let didShowKeyControl = wait(for: keyControl) { $0.exists }
    _ = try XCTUnwrap(didShowKeyControl ? keyControl : nil)
  }

  @MainActor
  private func waitForSelection(_ element: XCUIElement) -> Bool {
    wait(for: element) { $0.value as? String == "selected" }
  }

  @MainActor
  private func toggleState(_ element: XCUIElement) -> Bool? {
    if let value = element.value as? NSNumber {
      return value.boolValue
    }
    guard let value = element.value as? String else {
      return nil
    }
    switch value.lowercased() {
    case "0", "false", "off":
      return false
    case "1", "true", "on":
      return true
    default:
      return nil
    }
  }

  @MainActor
  private func waitForSettingsFile(
    containing expectedText: String,
    timeout: TimeInterval = 10
  ) -> Bool {
    wait(timeout: timeout) {
      self.settingsFile(at: self.settingsURL, contains: expectedText)
    }
  }

  @MainActor
  private var settingsURL: URL {
    stateHome.appendingPathComponent("settings.toml", isDirectory: false)
  }

  private func settingsFile(at url: URL, contains expectedText: String) -> Bool {
    guard let data = try? Data(contentsOf: url),
      let contents = String(data: data, encoding: .utf8)
    else {
      return false
    }
    return contents.contains(expectedText)
  }

}

private enum SettingsTab: String, CaseIterable {
  case general
  case terminal
  case notifications
  case codingAgents
  case advanced
  case about

  var sidebarIdentifier: String {
    SupatermUITestIdentifier.Settings.sidebar(rawValue)
  }

  var keyControlIdentifier: String {
    switch self {
    case .general:
      SupatermUITestIdentifier.Settings.restoreTerminalLayout
    case .terminal:
      SupatermUITestIdentifier.Settings.terminalFont
    case .notifications:
      SupatermUITestIdentifier.Settings.notificationsSystem
    case .codingAgents:
      SupatermUITestIdentifier.Settings.codingAgentsShowPanel
    case .advanced:
      SupatermUITestIdentifier.Settings.advancedVerboseLogging
    case .about:
      SupatermUITestIdentifier.Settings.aboutVersion
    }
  }
}
