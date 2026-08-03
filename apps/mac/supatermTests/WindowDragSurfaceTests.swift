import AppKit
import ComposableArchitecture
import SupaTheme
import SwiftUI
import Testing

@testable import supaterm

@MainActor
struct WindowDragSurfaceTests {
  private final class DragRecordingSurface: WindowDragSurfaceView {
    var dragEvent: NSEvent?

    override func dragWindow(with event: NSEvent) {
      dragEvent = event
    }
  }

  @Test
  func blankSurfaceStartsWindowDrag() throws {
    let surface = DragRecordingSurface(frame: NSRect(x: 0, y: 0, width: 240, height: 45))
    let window = NSWindow(
      contentRect: surface.frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    window.contentView = surface
    let event = try #require(
      NSEvent.mouseEvent(
        with: .leftMouseDown,
        location: NSPoint(x: 120, y: 22),
        modifierFlags: [],
        timestamp: ProcessInfo.processInfo.systemUptime,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 1,
        clickCount: 1,
        pressure: 1
      )
    )

    surface.mouseDown(with: event)

    #expect(surface.dragEvent === event)
  }

  @Test
  func controlsAboveSurfaceKeepTheirHitTarget() {
    let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 45))
    let surface = WindowDragSurfaceView(frame: contentView.bounds)
    let control = NSButton(title: "Control", target: nil, action: nil)
    control.frame = NSRect(x: 16, y: 12, width: 80, height: 24)
    contentView.addSubview(surface)
    contentView.addSubview(control)

    #expect(contentView.hitTest(NSPoint(x: 180, y: 22)) === surface)
    #expect(contentView.hitTest(NSPoint(x: 56, y: 24)) === control)
    #expect(surface.hitTest(NSPoint(x: 240, y: 22)) == nil)
  }

  @Test
  func headerControlsRemainAboveTheDragSurface() throws {
    let terminal = TerminalHostState(managesTerminalSurfaces: false)
    let store = Store(initialState: TerminalWindowFeature.State()) {
      TerminalWindowFeature()
    }
    let header = NSHostingView(
      rootView: TerminalWindowHeader(
        store: store,
        palette: Palette(colorScheme: .dark),
        terminal: terminal
      )
    )
    header.frame = NSRect(x: 0, y: 0, width: 240, height: TerminalSidebarLayout.scrollViewportTopInset)
    let window = NSWindow(
      contentRect: header.frame,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    window.contentView = header
    header.layoutSubtreeIfNeeded()

    let blankPoint = NSPoint(x: header.bounds.maxX - 2, y: header.bounds.midY)
    let leftBlankPoint = NSPoint(x: 2, y: header.bounds.midY)
    let controlPoint = NSPoint(
      x: WindowTrafficLightMetrics.edgePadding + WindowTrafficLightMetrics.buttonSize / 2,
      y: header.isFlipped
        ? WindowTrafficLightMetrics.edgePadding + WindowTrafficLightMetrics.buttonSize / 2
        : header.bounds.height - WindowTrafficLightMetrics.edgePadding
          - WindowTrafficLightMetrics.buttonSize / 2
    )
    let control = try #require(header.hitTest(controlPoint))

    #expect(header.hitTest(blankPoint) is WindowDragSurfaceView)
    #expect(header.hitTest(leftBlankPoint) is WindowDragSurfaceView)
    #expect(!(control is WindowDragSurfaceView))
  }
}
