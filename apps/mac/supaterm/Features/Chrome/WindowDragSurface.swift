import AppKit
import SwiftUI

struct WindowDragSurface: NSViewRepresentable {
  func makeNSView(context: Context) -> WindowDragSurfaceView {
    WindowDragSurfaceView()
  }

  func updateNSView(_ nsView: WindowDragSurfaceView, context: Context) {}
}

class WindowDragSurfaceView: NSView {
  override var mouseDownCanMoveWindow: Bool { false }

  override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
    true
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    bounds.contains(point) ? self : nil
  }

  override func mouseDown(with event: NSEvent) {
    dragWindow(with: event)
  }

  func dragWindow(with event: NSEvent) {
    window?.performDrag(with: event)
  }
}
