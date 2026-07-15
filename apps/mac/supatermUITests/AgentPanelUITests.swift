import AppKit
import XCTest

final class AgentPanelUITests: SupatermUITestCase {
  private static let sessionID = "agent-panel-ui-tests"
  private static let panelToggleDifference = 0.008

  @MainActor
  func testCommandIAndMenuItemToggleAgentPanel() async throws {
    _ = mainWindow
    try await sendClaudeEvent("session-start")
    try await assertAgentPanelMenuItem(isEnabled: true)

    let expandedPanel = try XCTUnwrap(panelPixels())

    app.typeKey("i", modifierFlags: .command)
    _ = try await requirePanelPixels {
      expandedPanel.difference(from: $0) > Self.panelToggleDifference
    }

    app.typeKey("i", modifierFlags: .command)
    _ = try await requirePanelPixels {
      expandedPanel.difference(from: $0) < Self.panelToggleDifference / 2
    }

    try clickMenuItem(.toggleAgentPanel)
    _ = try await requirePanelPixels {
      expandedPanel.difference(from: $0) > Self.panelToggleDifference
    }
  }

  @MainActor
  func testClaudeLifecycleUpdatesSidebarAndPanel() async throws {
    _ = mainWindow

    let tabRows = app.buttons.matching(
      identifier: SupatermUITestIdentifier.Accessibility.sidebarTabRow
    )
    let firstTab = tabRows.element(boundBy: 0)
    guard firstTab.waitForExistence(timeout: 30) else {
      XCTFail("Initial sidebar tab row did not appear")
      return
    }

    try await sendClaudeEvent("session-start")
    try await sendClaudeEvent("user-prompt-submit")

    await assertEventually(firstTab, timeout: .seconds(30)) {
      $0.label.contains("Agent activity: Running")
    }

    try await sendClaudeEvent("notification")
    try clickMenuItem(.newTab)

    let secondTab = tabRows.element(boundBy: 1)
    await assertEventually(secondTab, timeout: .seconds(30)) { $0.exists }
    firstTab.click()
    secondTab.click()
    await assertEventually(firstTab, timeout: .seconds(30)) {
      $0.label.contains("Agent activity: Needs input")
    }

    firstTab.click()
    try await assertAgentPanelMenuItem(isEnabled: true)
    try await sendClaudeEvent("stop")

    await assertEventually(firstTab, timeout: .seconds(30)) {
      $0.label.contains("Done.") && !$0.label.contains("Agent activity:")
    }
    try await sendClaudeEvent("session-end")
    try await assertAgentPanelMenuItem(isEnabled: false)
  }

  @MainActor
  private func assertAgentPanelMenuItem(isEnabled: Bool) async throws {
    let topLevelMenu = app.menuBars.menuBarItems["View"]
    guard topLevelMenu.waitForExistence(timeout: 10) else {
      XCTFail("View menu did not appear")
      return
    }
    topLevelMenu.click()

    let item = menuItem(.toggleAgentPanel)
    guard item.waitForExistence(timeout: 10) else {
      XCTFail("Agent panel menu item did not appear")
      return
    }
    await assertEventually(item) { $0.isEnabled == isEnabled }
    app.typeKey(.escape, modifierFlags: [])
  }

  @MainActor
  private func sendClaudeEvent(_ event: String) async throws {
    let terminal = app.textViews.firstMatch
    guard await wait(for: terminal, timeout: .seconds(30), until: { $0.exists && $0.isHittable })
    else {
      XCTFail("Terminal did not become ready")
      return
    }

    terminal.click()
    terminal.typeText(
      "\"$SUPATERM_CLI_PATH\" internal dev claude \(event) --session-id \(Self.sessionID)"
    )
    terminal.typeKey(.return, modifierFlags: [])

    let expectedOutput = "sent \(event) for session \(Self.sessionID)"
    await assertEventually(terminal, timeout: .seconds(30)) {
      ($0.value as? String)?.contains(expectedOutput) == true
    }
  }

  @MainActor
  private func requirePanelPixels(
    timeout: Duration = .seconds(5),
    until condition: (PanelPixels) -> Bool
  ) async throws -> PanelPixels {
    var matchingPixels: PanelPixels?
    let terminal = app.textViews.firstMatch
    _ = await wait(for: terminal, timeout: timeout) { _ in
      guard let pixels = panelPixels(), condition(pixels) else { return false }
      matchingPixels = pixels
      return true
    }
    return try XCTUnwrap(matchingPixels)
  }

  @MainActor
  private func panelPixels() -> PanelPixels? {
    let image = app.textViews.firstMatch.screenshot().image
    guard
      let representation = image.tiffRepresentation.flatMap(NSBitmapImageRep.init),
      !representation.isPlanar,
      let bitmapData = representation.bitmapData
    else { return nil }

    let bytesPerPixel = representation.bitsPerPixel / 8
    guard bytesPerPixel >= 3 else { return nil }

    let width = representation.pixelsWide
    let height = representation.pixelsHigh
    let firstX = width * 11 / 20
    let lastY = height / 4
    var bytes: [UInt8] = []
    bytes.reserveCapacity((width - firstX) * lastY * 3 / 4)

    for y in stride(from: 0, to: lastY, by: 2) {
      let row = bitmapData.advanced(by: y * representation.bytesPerRow)
      for x in stride(from: firstX, to: width, by: 2) {
        let pixel = row.advanced(by: x * bytesPerPixel)
        bytes.append(pixel[0])
        bytes.append(pixel[1])
        bytes.append(pixel[2])
      }
    }
    return PanelPixels(bytes: bytes)
  }

  @MainActor
  private func assertEventually(
    _ element: XCUIElement,
    timeout: Duration = .seconds(10),
    file: StaticString = #filePath,
    line: UInt = #line,
    until condition: (XCUIElement) -> Bool
  ) async {
    let didMatch = await wait(for: element, timeout: timeout, until: condition)
    XCTAssertTrue(didMatch, file: file, line: line)
  }

  private struct PanelPixels {
    let bytes: [UInt8]

    func difference(from other: Self) -> Double {
      guard bytes.count == other.bytes.count, !bytes.isEmpty else { return 1 }
      let totalDifference = zip(bytes, other.bytes).reduce(into: Int64(0)) { result, pair in
        result += Int64(abs(Int(pair.0) - Int(pair.1)))
      }
      return Double(totalDifference) / Double(bytes.count * 255)
    }
  }
}
