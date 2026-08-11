import AppKit
import Foundation
import XCTest

final class PaneChromeUITests: SupatermUITestCase {
  @MainActor
  func testTopBarTitleFollowsFocusedPane() async throws {
    let leftPane = try await requireVisiblePanes(count: 1)[0]
    leftPane.click()
    try await requireFocus(on: leftPane)

    let leftTitle = "pane-title-L-\(UUID().uuidString.prefix(8))"
    leftPane.typeText("printf '\\033]0;\(leftTitle)\\007'; sleep 600\n")
    let didSetLeftTitle = await wait(for: leftPane, timeout: .seconds(30)) {
      $0.label == leftTitle
    }
    XCTAssertTrue(didSetLeftTitle)

    try clickMenuItem(.toggleSidebar)
    let didCollapseSidebar = await waitForSidebarCollapsed()
    XCTAssertTrue(didCollapseSidebar)

    let leftTopBarTitle = app.staticTexts[leftTitle]
    let didShowLeftTitle = await wait(for: leftTopBarTitle) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didShowLeftTitle)

    try clickMenuItem(.splitRight)
    let panes = try await requireVisiblePanes(count: 2)
    let rightPane = try XCTUnwrap(panes.max { $0.frame.midX < $1.frame.midX })
    try await requireFocus(on: rightPane)

    let rightTitle = "pane-title-R-\(UUID().uuidString.prefix(8))"
    rightPane.typeText("printf '\\033]0;\(rightTitle)\\007'; sleep 600\n")
    let didSetRightTitle = await wait(for: rightPane, timeout: .seconds(30)) {
      $0.label == rightTitle
    }
    XCTAssertTrue(didSetRightTitle)

    let rightTopBarTitle = app.staticTexts[rightTitle]
    let didShowRightTitle = await wait(for: rightTopBarTitle) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didShowRightTitle)
    let didHideLeftTitle = await wait(for: leftTopBarTitle) { !$0.exists }
    XCTAssertTrue(didHideLeftTitle)

    try clickMenuItem(.selectSplitLeft)
    try await requireFocus(on: leftPane)
    let didRestoreLeftTitle = await wait(for: leftTopBarTitle) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didRestoreLeftTitle)
    let didHideRightTitle = await wait(for: rightTopBarTitle) { !$0.exists }
    XCTAssertTrue(didHideRightTitle)

    try clickMenuItem(.selectSplitRight)
    try await requireFocus(on: rightPane)
    let didRestoreRightTitle = await wait(for: rightTopBarTitle) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didRestoreRightTitle)
    let didRemoveLeftTitle = await wait(for: leftTopBarTitle) { !$0.exists }
    XCTAssertTrue(didRemoveLeftTitle)

    leftPane.click()
    app.typeKey("c", modifierFlags: .control)
    rightPane.click()
    app.typeKey("c", modifierFlags: .control)
  }

  @MainActor
  func testTopBarRendersSplitButtonOverTerminalBackground() async throws {
    let pane = try await requireVisiblePanes(count: 1)[0]

    let splitRightButton = app.buttons["Split right"]
    let didShowSplitRightButton = await wait(for: splitRightButton) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didShowSplitRightButton)

    let buttonMetrics = try imageMetrics(in: splitRightButton.screenshot().image)
    let paneMetrics = try imageMetrics(in: pane.screenshot().image)
    XCTAssertGreaterThan(buttonMetrics.luminanceRange, 0.08)
    XCTAssertLessThanOrEqual(buttonMetrics.dominantRGB.distance(to: paneMetrics.dominantRGB), 2)
  }

  @MainActor
  func testCollapsingSidebarHidesItsHeaderFromDetailPane() async throws {
    _ = mainWindow
    let spaceSwitcher = element(SupatermUITestIdentifier.Accessibility.titlebarSpaceSwitcher)

    let didShowSidebarHeader = await wait(timeout: .seconds(30)) {
      spaceSwitcher.exists
        && spaceSwitcher.isHittable
    }
    XCTAssertTrue(didShowSidebarHeader)

    app.typeKey("s", modifierFlags: .command)

    let didHideSidebarHeader = await wait {
      self.showSidebarButton.exists
        && self.showSidebarButton.isHittable
        && !spaceSwitcher.isHittable
    }
    XCTAssertTrue(didHideSidebarHeader)
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
