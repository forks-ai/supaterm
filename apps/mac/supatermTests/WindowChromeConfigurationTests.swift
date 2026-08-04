import AppKit
import Testing

@testable import supaterm

@MainActor
struct WindowChromeConfigurationTests {
  @Test
  func trafficLightsUseNativeWindowButtons() throws {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1_440, height: 900),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    let view = WindowTrafficLightsView(reduceMotion: true)
    view.appearance = NSAppearance(named: .aqua)
    view.frame = NSRect(x: 0, y: 0, width: 100, height: 80)
    window.contentView?.addSubview(view)
    view.layoutSubtreeIfNeeded()

    let buttons = view.subviews.compactMap { $0 as? NSButton }
    let expectedButtons = [
      NSWindow.standardWindowButton(.closeButton, for: window.styleMask),
      NSWindow.standardWindowButton(.miniaturizeButton, for: window.styleMask),
      NSWindow.standardWindowButton(.zoomButton, for: window.styleMask),
    ].compactMap { $0 }

    #expect(buttons.count == 3)
    #expect(
      buttons.map { ObjectIdentifier(type(of: $0)) }
        == expectedButtons.map { ObjectIdentifier(type(of: $0)) }
    )
    #expect(buttons.map(\.action) == expectedButtons.map(\.action))
    #expect(buttons.allSatisfy { $0.alphaValue == 0.1 })
    #expect(buttons[0].frame.minX == WindowTrafficLightMetrics.edgePadding)
    #expect(buttons[0].frame.width == WindowTrafficLightMetrics.buttonSize)
    #expect(buttons[1].frame.minX - buttons[0].frame.maxX == WindowTrafficLightMetrics.buttonSpacing)

    view.appearance = NSAppearance(named: .darkAqua)
    view.viewDidChangeEffectiveAppearance()

    #expect(buttons.allSatisfy { $0.alphaValue == 0.33 })
  }

  @Test
  func trafficLightMetricsMatchUnifiedTitlebar() throws {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1_440, height: 900),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.toolbar = NSToolbar(identifier: "test-toolbar")
    window.toolbarStyle = .unified

    let frameView = try #require(window.contentView?.superview)
    frameView.layoutSubtreeIfNeeded()
    let closeButton = try #require(window.standardWindowButton(.closeButton))
    let minimizeButton = try #require(window.standardWindowButton(.miniaturizeButton))
    let closeFrame = frameView.convert(closeButton.bounds, from: closeButton)
    let minimizeFrame = frameView.convert(minimizeButton.bounds, from: minimizeButton)

    #expect(closeFrame.minX == WindowTrafficLightMetrics.edgePadding)
    #expect(frameView.bounds.maxY - closeFrame.maxY == WindowTrafficLightMetrics.edgePadding)
    #expect(closeFrame.width == WindowTrafficLightMetrics.buttonSize)
    #expect(minimizeFrame.minX - closeFrame.maxX == WindowTrafficLightMetrics.buttonSpacing)
  }

  @Test
  func applyHidesTheTitlebarAndKeepsSidebarTrafficLights() throws {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1_440, height: 900),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    window.toolbar = NSToolbar(identifier: "test-toolbar")
    window.titleVisibility = .visible
    window.titlebarAppearsTransparent = false
    window.isMovableByWindowBackground = false
    let titlebarClose = try #require(window.standardWindowButton(.closeButton))

    let view = WindowTrafficLightsView(reduceMotion: true)
    view.frame = NSRect(x: 0, y: 0, width: 100, height: 80)
    window.contentView?.addSubview(view)

    WindowChromeConfiguration.apply(to: window)
    WindowChromeConfiguration.apply(to: window)

    #expect(window.titleVisibility == .hidden)
    #expect(window.titlebarAppearsTransparent)
    #expect(window.titlebarSeparatorStyle == .none)
    #expect(window.toolbar == nil)
    #expect(window.isMovableByWindowBackground == false)
    #expect(titlebarClose.isHiddenOrHasHiddenAncestor)

    let sidebarButtons = view.subviews.compactMap { $0 as? NSButton }
    #expect(sidebarButtons.count == 3)
    #expect(sidebarButtons.allSatisfy { !$0.isHiddenOrHasHiddenAncestor })
  }

  @Test
  func titleApplierNamesTheWindowAndFollowsChanges() throws {
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1_440, height: 900),
      styleMask: [.titled, .closable, .miniaturizable, .resizable],
      backing: .buffered,
      defer: false
    )
    let contentView = try #require(window.contentView)
    let applier = WindowTitleApplierView()
    applier.appliedTitle = "Research"

    contentView.addSubview(applier)
    #expect(window.title == "Research")

    applier.appliedTitle = "Shipping"
    #expect(window.title == "Shipping")
  }
}
