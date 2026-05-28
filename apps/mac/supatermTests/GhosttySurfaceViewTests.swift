import AppKit
import GhosttyKit
import SwiftUI
import Testing

@testable import supaterm

struct GhosttySurfaceViewTests {
  @Test
  func legacyScrollerFlashRequiresLegacyStyleAndMotionAllowance() {
    #expect(
      GhosttySurfaceScrollView.shouldFlashLegacyScrollers(
        scrollerStyle: .legacy,
        reduceMotion: false
      )
    )
    #expect(
      !GhosttySurfaceScrollView.shouldFlashLegacyScrollers(
        scrollerStyle: .overlay,
        reduceMotion: false
      )
    )
    #expect(
      !GhosttySurfaceScrollView.shouldFlashLegacyScrollers(
        scrollerStyle: .legacy,
        reduceMotion: true
      )
    )
    #expect(
      !GhosttySurfaceScrollView.shouldFlashLegacyScrollers(
        scrollerStyle: .overlay,
        reduceMotion: true
      )
    )
  }

  @Test
  func reportedSurfaceSizeUsesScrollContentWidth() {
    #expect(
      GhosttySurfaceScrollView.reportedSurfaceSize(
        scrollContentSize: CGSize(width: 799, height: 600),
        surfaceFrameSize: CGSize(width: 816, height: 600)
      ) == CGSize(width: 799, height: 600)
    )
  }

  @Test
  @MainActor
  func wrapperSafeAreaInsetsAreZero() {
    initializeGhosttyForTests()

    let surfaceView = GhosttySurfaceView(
      runtime: GhosttyRuntime(),
      tabID: UUID(),
      workingDirectory: nil,
      context: GHOSTTY_SURFACE_CONTEXT_TAB
    )
    let wrapper = GhosttySurfaceScrollView(surfaceView: surfaceView)

    #expect(wrapper.safeAreaInsets.top == 0)
    #expect(wrapper.safeAreaInsets.left == 0)
    #expect(wrapper.safeAreaInsets.bottom == 0)
    #expect(wrapper.safeAreaInsets.right == 0)
  }

  @Test
  @MainActor
  func searchOverlayUpdateDoesNotStealFocusAfterSplit() async throws {
    initializeGhosttyForTests()

    let host = TerminalHostState(runtime: GhosttyRuntime())
    host.handleCommand(.ensureInitialTab(focusing: false, startupCommand: nil))
    let sourceSurface = try #require(host.selectedSurfaceView)
    sourceSurface.bridge.state.searchNeedle = ""
    sourceSurface.bridge.state.searchFocusCount = 1

    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
      styleMask: [.titled],
      backing: .buffered,
      defer: false
    )

    let container = NSView(frame: window.contentView?.bounds ?? .zero)
    let overlay = NSHostingView(
      rootView: GhosttySurfaceSearchOverlay(surfaceView: sourceSurface)
    )
    sourceSurface.frame = container.bounds
    overlay.frame = container.bounds
    window.contentView = container
    container.addSubview(sourceSurface)
    container.addSubview(overlay)
    window.makeKeyAndOrderFront(nil)

    let searchField = try await searchField(in: container)
    window.makeFirstResponder(searchField)
    try #require(
      window.firstResponder === searchField || window.firstResponder === searchField.currentEditor()
    )

    #expect(host.performSplitAction(.newSplit(direction: .right), for: sourceSurface.id))
    let targetSurface = try #require(host.selectedSurfaceView)
    #expect(targetSurface !== sourceSurface)
    targetSurface.frame = container.bounds
    container.addSubview(targetSurface)
    await Task.yield()
    await Task.yield()

    #expect(window.firstResponder === targetSurface)

    overlay.removeFromSuperview()
    let rebuiltOverlay = NSHostingView(
      rootView: GhosttySurfaceSearchOverlay(surfaceView: sourceSurface)
    )
    rebuiltOverlay.frame = container.bounds
    container.addSubview(rebuiltOverlay)
    try? await Task.sleep(for: .milliseconds(50))

    #expect(window.firstResponder === targetSurface)
  }
}

@MainActor
private func searchField(in root: NSView) async throws -> NSTextField {
  for _ in 0..<5 {
    root.layoutSubtreeIfNeeded()
    if let field = findSearchField(in: root) {
      return field
    }
    await Task.yield()
  }
  return try #require(findSearchField(in: root))
}

@MainActor
private func findSearchField(in root: NSView) -> NSTextField? {
  if let field = root as? NSTextField, field.placeholderString == "Search" {
    return field
  }
  for subview in root.subviews {
    if let field = findSearchField(in: subview) {
      return field
    }
  }
  return nil
}
