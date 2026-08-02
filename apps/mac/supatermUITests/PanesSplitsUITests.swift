import AppKit
import XCTest

final class PanesSplitsUITests: SupatermUITestCase {
  private static let paneIdentifierPrefix = "terminal.pane."

  @MainActor
  private var terminalPanes: XCUIElementQuery {
    app.textViews.matching(
      NSPredicate(format: "identifier BEGINSWITH %@", Self.paneIdentifierPrefix)
    )
  }

  @MainActor
  private var focusedTerminalPanes: XCUIElementQuery {
    terminalPanes.matching(NSPredicate(format: "hasKeyboardFocus == true"))
  }

  @MainActor
  func testSplitRightCreatesTwoVisiblePanes() throws {
    _ = try requireVisiblePanes(count: 1)

    try clickMenuItem(.splitRight)

    let panes = try requireVisiblePanes(count: 2)
    XCTAssertGreaterThan(
      abs(panes[0].frame.midX - panes[1].frame.midX),
      abs(panes[0].frame.midY - panes[1].frame.midY)
    )
  }

  @MainActor
  func testSplitDownCreatesTwoVisiblePanes() throws {
    _ = try requireVisiblePanes(count: 1)

    try clickMenuItem(.splitDown)

    let panes = try requireVisiblePanes(count: 2)
    XCTAssertGreaterThan(
      abs(panes[0].frame.midY - panes[1].frame.midY),
      abs(panes[0].frame.midX - panes[1].frame.midX)
    )
  }

  @MainActor
  func testDirectionalFocusNavigationMovesFocusBetweenPanes() throws {
    _ = try requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try requireVisiblePanes(count: 2)
    let leftPane = try XCTUnwrap(panes.min { $0.frame.midX < $1.frame.midX })
    let rightPane = try XCTUnwrap(panes.max { $0.frame.midX < $1.frame.midX })

    try clickMenuItem(.selectSplitLeft)
    try requireFocus(on: leftPane)

    try clickMenuItem(.selectSplitRight)
    try requireFocus(on: rightPane)
  }

  @MainActor
  func testSplitWhileSearchOpenFocusesNewPane() throws {
    let originalPane = try requireVisiblePanes(count: 1)[0]
    originalPane.click()
    let originalIdentifier = originalPane.identifier

    app.typeKey("f", modifierFlags: .command)
    let searchField = app.textFields[SupatermUITestIdentifier.Accessibility.searchField]
    XCTAssertTrue(searchField.waitForExistence(timeout: 10))
    searchField.typeText("SPLITFOCUSNEEDLE")
    XCTAssertEqual(searchField.value as? String, "SPLITFOCUSNEEDLE")

    try clickMenuItem(.splitRight)
    let panes = try requireVisiblePanes(count: 2)
    let newPane = try XCTUnwrap(panes.first { $0.identifier != originalIdentifier })

    let remountedSearchField = app.textFields[
      SupatermUITestIdentifier.Accessibility.searchField
    ]
    XCTAssertTrue(remountedSearchField.waitForExistence(timeout: 10))
    try requireFocus(on: newPane)

    app.typeText(
      "printf '\\x53\\x50\\x4C\\x49\\x54\\x46\\x4F\\x43\\x55\\x53\\x4D\\x41\\x52\\x4B\\x45\\x52\\n'"
    )
    app.typeKey(.return, modifierFlags: [])
    let markerPrinted = wait(for: newPane, timeout: 30) {
      ($0.value as? String)?.contains("SPLITFOCUSMARKER") == true
    }
    XCTAssertTrue(markerPrinted)
    XCTAssertEqual(remountedSearchField.value as? String, "SPLITFOCUSNEEDLE")
  }

  @MainActor
  func testTopBarTitleFollowsFocusedPane() throws {
    let leftPane = try requireVisiblePanes(count: 1)[0]
    leftPane.click()
    try requireFocus(on: leftPane)

    let leftTitle = "pane-title-L-\(UUID().uuidString.prefix(8))"
    leftPane.typeText("printf '\\033]0;\(leftTitle)\\007'; sleep 600\n")
    let didSetLeftTitle = wait(for: leftPane, timeout: 30) {
      $0.label == leftTitle
    }
    XCTAssertTrue(didSetLeftTitle)

    let sidebarTabRow = sidebarTabRows.firstMatch
    try clickMenuItem(.toggleSidebar)
    let didHideSidebar = wait(for: sidebarTabRow) { !$0.isHittable }
    XCTAssertTrue(didHideSidebar)

    let leftTopBarTitle = app.staticTexts[leftTitle]
    let didShowLeftTitle = wait(for: leftTopBarTitle) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didShowLeftTitle)

    try clickMenuItem(.splitRight)
    let panes = try requireVisiblePanes(count: 2)
    let rightPane = try XCTUnwrap(panes.max { $0.frame.midX < $1.frame.midX })
    try requireFocus(on: rightPane)

    let rightTitle = "pane-title-R-\(UUID().uuidString.prefix(8))"
    rightPane.typeText("printf '\\033]0;\(rightTitle)\\007'; sleep 600\n")
    let didSetRightTitle = wait(for: rightPane, timeout: 30) {
      $0.label == rightTitle
    }
    XCTAssertTrue(didSetRightTitle)

    let rightTopBarTitle = app.staticTexts[rightTitle]
    let didShowRightTitle = wait(for: rightTopBarTitle) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didShowRightTitle)
    let didHideLeftTitle = wait(for: leftTopBarTitle) { !$0.exists }
    XCTAssertTrue(didHideLeftTitle)

    try clickMenuItem(.selectSplitLeft)
    try requireFocus(on: leftPane)
    let didRestoreLeftTitle = wait(for: leftTopBarTitle) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didRestoreLeftTitle)
    let didHideRightTitle = wait(for: rightTopBarTitle) { !$0.exists }
    XCTAssertTrue(didHideRightTitle)

    try clickMenuItem(.selectSplitRight)
    try requireFocus(on: rightPane)
    let didRestoreRightTitle = wait(for: rightTopBarTitle) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didRestoreRightTitle)
    let didRemoveLeftTitle = wait(for: leftTopBarTitle) { !$0.exists }
    XCTAssertTrue(didRemoveLeftTitle)

    leftPane.click()
    app.typeKey("c", modifierFlags: .control)
    rightPane.click()
    app.typeKey("c", modifierFlags: .control)
  }

  @MainActor
  func testTopBarRendersSplitButtonOverTerminalBackground() throws {
    let pane = try requireVisiblePanes(count: 1)[0]

    let splitRightButton = app.buttons["Split right"]
    let didShowSplitRightButton = wait(for: splitRightButton) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didShowSplitRightButton)

    let buttonMetrics = try imageMetrics(in: splitRightButton.screenshot().image)
    let paneMetrics = try imageMetrics(in: pane.screenshot().image)
    XCTAssertGreaterThan(buttonMetrics.luminanceRange, 0.08)
    XCTAssertLessThanOrEqual(buttonMetrics.dominantRGB.distance(to: paneMetrics.dominantRGB), 2)
  }

  @MainActor
  func testCollapsingSidebarHidesItsHeaderFromDetailPane() throws {
    _ = mainWindow
    let spaceSwitcher = element(SupatermUITestIdentifier.Accessibility.titlebarSpaceSwitcher)
    let windowControls = [
      app.buttons["Close window"],
      app.buttons["Minimize window"],
      app.buttons["Enter full screen"],
    ]

    let didShowSidebarHeader = wait(timeout: 30) {
      spaceSwitcher.exists
        && spaceSwitcher.isHittable
        && windowControls.allSatisfy { $0.exists && $0.isHittable }
    }
    XCTAssertTrue(didShowSidebarHeader)

    try clickMenuItem(.toggleSidebar)

    let showSidebar = app.buttons["Show sidebar"]
    let didHideSidebarHeader = wait {
      showSidebar.exists
        && showSidebar.isHittable
        && !spaceSwitcher.isHittable
        && windowControls.allSatisfy { !$0.isHittable }
    }
    XCTAssertTrue(didHideSidebarHeader)
  }

  @MainActor
  func testExitingShellClosesPaneWithoutConfirmation() throws {
    _ = try requireVisiblePanes(count: 1)
    let originalIdentifier = terminalPanes.element(boundBy: 0).identifier

    try clickMenuItem(.splitRight)
    let panes = try requireVisiblePanes(count: 2)
    let newPane = try XCTUnwrap(panes.first { $0.identifier != originalIdentifier })
    newPane.click()
    try requireFocus(on: newPane)

    newPane.typeText("exit\n")
    let didClosePane = wait(for: mainWindow, timeout: 30) { _ in
      self.terminalPanes.count == 1
        && self.terminalPanes.element(boundBy: 0).identifier == originalIdentifier
    }
    guard didClosePane else {
      XCTFail("Exited pane did not close while preserving its sibling")
      return
    }

    XCTAssertEqual(mainWindow.sheets.count, 0)
    XCTAssertFalse(
      app.buttons[SupatermUITestIdentifier.Accessibility.dialogConfirm].exists
    )

    let survivor = terminalPanes.element(boundBy: 0)
    try requireFocus(on: survivor)

    let token = UUID().uuidString.prefix(8)
    app.typeText("echo exit-\"close\"-\(token)\n")
    let survivorReceivedInput = wait(for: survivor, timeout: 30) {
      ($0.value as? String)?.contains("exit-close-\(token)") == true
    }
    XCTAssertTrue(survivorReceivedInput)
  }

  @MainActor
  func testToggleSplitZoomFocusesTargetPane() throws {
    _ = try requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try requireVisiblePanes(count: 2)
    let leftPane = try XCTUnwrap(panes.min { $0.frame.midX < $1.frame.midX })
    let paneIdentifiers = Set(panes.map(\.identifier))

    try clickMenuItem(.selectSplitLeft)
    try requireFocus(on: leftPane)

    try clickMenuItem(.zoomSplit)
    let zoomedPanes = try requireVisiblePanes(count: 1)
    XCTAssertEqual(zoomedPanes[0].identifier, leftPane.identifier)
    try requireFocus(on: leftPane)

    try clickMenuItem(.zoomSplit)
    let restoredPanes = try requireVisiblePanes(count: 2)
    XCTAssertEqual(Set(restoredPanes.map(\.identifier)), paneIdentifiers)
    try requireFocus(on: leftPane)
  }

  @MainActor
  func testCommandWClosesFocusedPaneNotWindow() throws {
    try relaunchWithoutCloseConfirmation()

    _ = try requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try requireVisiblePanes(count: 2)
    let leftPane = try XCTUnwrap(panes.min { $0.frame.midX < $1.frame.midX })
    let rightPane = try XCTUnwrap(panes.max { $0.frame.midX < $1.frame.midX })
    let leftPaneIdentifier = leftPane.identifier

    rightPane.click()
    try requireFocus(on: rightPane)
    app.typeKey("w", modifierFlags: .command)

    let survivors = try requireVisiblePanes(count: 1)
    XCTAssertEqual(survivors[0].identifier, leftPaneIdentifier)
    XCTAssertEqual(mainWindow.sheets.count, 0)
    XCTAssertEqual(app.windows.count, 1)
    XCTAssertTrue(mainWindow.exists)
  }

  @MainActor
  func testContextMenuClosesClickedPaneWhenSessionPersistenceIsDisabled() throws {
    try assertContextMenuClosesClickedPane(zmxSessionsEnabled: false)
  }

  @MainActor
  func testContextMenuClosesClickedPaneWhenSessionPersistenceIsEnabled() throws {
    try assertContextMenuClosesClickedPane(zmxSessionsEnabled: true)
  }

  @MainActor
  private func assertContextMenuClosesClickedPane(zmxSessionsEnabled: Bool) throws {
    try relaunchWithoutCloseConfirmation(zmxSessionsEnabled: zmxSessionsEnabled)
    _ = try requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try requireVisiblePanes(count: 2)
    let leftPane = try XCTUnwrap(panes.min { $0.frame.midX < $1.frame.midX })
    let rightPane = try XCTUnwrap(panes.max { $0.frame.midX < $1.frame.midX })

    rightPane.click()
    try requireFocus(on: rightPane)
    let marker = "close-pane-ready-\(UUID().uuidString.prefix(8))"
    rightPane.typeText("echo \(marker)\n")
    let shellIsReady = wait(for: rightPane, timeout: 30) {
      ($0.value as? String)?.contains(marker) == true
    }
    XCTAssertTrue(shellIsReady)

    leftPane.click()
    try requireFocus(on: leftPane)
    rightPane.rightClick()
    let closePane = app.menuItems["Close Pane"].firstMatch
    try require(closePane)
    closePane.click()

    let survivors = try requireVisiblePanes(count: 1)
    XCTAssertEqual(survivors[0].identifier, leftPane.identifier)
  }

  @MainActor
  func testZoomSplitHidesAndRestoresOtherPane() throws {
    _ = try requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try requireVisiblePanes(count: 2)
    let paneIdentifiers = Set(panes.map(\.identifier))

    try clickMenuItem(.zoomSplit)

    let zoomedPanes = try requireVisiblePanes(count: 1)
    XCTAssertTrue(paneIdentifiers.contains(zoomedPanes[0].identifier))

    try clickMenuItem(.zoomSplit)

    let restoredPanes = try requireVisiblePanes(count: 2)
    XCTAssertEqual(Set(restoredPanes.map(\.identifier)), paneIdentifiers)
  }

  @MainActor
  func testResizeAndEqualizeChangeLayoutWithoutLosingPanes() throws {
    _ = try requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try requireVisiblePanes(count: 2)
    let leftPane = try XCTUnwrap(panes.min { $0.frame.midX < $1.frame.midX })
    let initialFrame = leftPane.frame
    let paneIdentifiers = Set(panes.map(\.identifier))

    for _ in 0..<3 {
      try clickMenuItem(.moveSplitDividerLeft)
    }

    let didResize = wait(for: leftPane) {
      $0.exists && $0.frame.width < initialFrame.width - 5
    }
    guard didResize else {
      XCTFail("Split divider did not move left")
      return
    }
    let resizedPanes = try requireVisiblePanes(count: 2)
    XCTAssertEqual(Set(resizedPanes.map(\.identifier)), paneIdentifiers)

    try clickMenuItem(.equalizeSplits)

    let didEqualize = wait(for: leftPane) {
      $0.exists && abs($0.frame.width - initialFrame.width) < 2
    }
    XCTAssertTrue(didEqualize)
    let equalizedPanes = try requireVisiblePanes(count: 2)
    XCTAssertEqual(Set(equalizedPanes.map(\.identifier)), paneIdentifiers)
  }

  @MainActor
  func testClosingBusyPaneRequiresConfirmation() throws {
    _ = try requireVisiblePanes(count: 1)
    try clickMenuItem(.splitRight)
    let panes = try requireVisiblePanes(count: 2)
    let rightPane = try XCTUnwrap(panes.max { $0.frame.midX < $1.frame.midX })
    rightPane.click()
    try requireFocus(on: rightPane)

    let processSentinel = "pane-busy"
    rightPane.typeText("printf '\\033]0;\(processSentinel)\\007'; sleep 600\n")
    let didStartProcess = wait(for: rightPane, timeout: 30) {
      $0.label == processSentinel
    }
    guard didStartProcess else {
      XCTFail("Busy pane process did not start")
      return
    }

    try clickMenuItem(.closeSurface)

    let cancelButton = mainWindow.sheets.firstMatch.buttons["Cancel"]
    guard cancelButton.waitForExistence(timeout: 10) else {
      XCTFail("Close confirmation did not appear")
      return
    }
    cancelButton.click()
    _ = try requireVisiblePanes(count: 2)

    rightPane.click()
    try requireFocus(on: rightPane)
    try clickMenuItem(.closeSurface)

    let confirmButton = mainWindow.sheets.firstMatch.buttons["Close"]
    guard confirmButton.waitForExistence(timeout: 10) else {
      XCTFail("Close confirmation did not reappear")
      return
    }
    confirmButton.click()

    _ = try requireVisiblePanes(count: 1)
  }

  @MainActor
  private func requireVisiblePanes(count expectedCount: Int) throws -> [XCUIElement] {
    let didReachCount = wait(for: mainWindow, timeout: 30) { _ in
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
  private func requireFocus(on pane: XCUIElement) throws {
    let focusedPane = focusedTerminalPanes.matching(identifier: pane.identifier).firstMatch
    let didFocus = wait(for: focusedPane) { $0.exists }
    XCTAssertTrue(didFocus, "Expected pane \(pane.identifier) to have keyboard focus")
  }

  @MainActor
  private func relaunchWithoutCloseConfirmation(zmxSessionsEnabled: Bool? = nil) throws {
    let ghosttyConfigDirectory = stateHome.appendingPathComponent("ghostty", isDirectory: true)
    try FileManager.default.createDirectory(
      at: ghosttyConfigDirectory,
      withIntermediateDirectories: true
    )
    try Data("confirm-close-surface = false\n".utf8).write(
      to: ghosttyConfigDirectory.appendingPathComponent("config")
    )
    if let zmxSessionsEnabled {
      try Data(
        """
        [terminal]
        zmx_sessions_enabled = \(zmxSessionsEnabled)

        """.utf8
      ).write(to: stateHome.appendingPathComponent("settings.toml"))
    }
    app.launchEnvironment["XDG_CONFIG_HOME"] = stateHome.path
    try relaunch()
  }

  private func imageMetrics(in image: NSImage) throws -> ImageMetrics {
    let representation = try XCTUnwrap(image.tiffRepresentation)
    let bitmap = try XCTUnwrap(NSBitmapImageRep(data: representation))
    var minimum = CGFloat(1)
    var maximum = CGFloat(0)
    var counts: [RGB: Int] = [:]

    for y in 0..<bitmap.pixelsHigh {
      for x in 0..<bitmap.pixelsWide {
        guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else {
          continue
        }
        let rgb = RGB(
          red: Int((color.redComponent * 255).rounded()),
          green: Int((color.greenComponent * 255).rounded()),
          blue: Int((color.blueComponent * 255).rounded())
        )
        let luminance =
          0.2126 * color.redComponent
          + 0.7152 * color.greenComponent
          + 0.0722 * color.blueComponent
        minimum = min(minimum, luminance)
        maximum = max(maximum, luminance)
        counts[rgb, default: 0] += 1
      }
    }

    return try ImageMetrics(
      luminanceRange: maximum - minimum,
      dominantRGB: XCTUnwrap(counts.max { $0.value < $1.value }?.key)
    )
  }
}

private struct ImageMetrics {
  let luminanceRange: CGFloat
  let dominantRGB: RGB
}

private struct RGB: Hashable {
  let red: Int
  let green: Int
  let blue: Int

  func distance(to other: Self) -> Int {
    max(abs(red - other.red), abs(green - other.green), abs(blue - other.blue))
  }
}
