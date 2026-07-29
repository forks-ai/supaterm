import AppKit
import SwiftUI

struct WindowBackgroundEffectView: NSViewRepresentable {
  func makeNSView(context: Context) -> NSVisualEffectView {
    let view = NSVisualEffectView()
    Self.configure(view)
    return view
  }

  func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
    Self.configure(nsView)
  }

  static func configure(_ view: NSVisualEffectView) {
    view.material = .underWindowBackground
    view.blendingMode = .behindWindow
    view.state = .followsWindowActiveState
    view.isEmphasized = true
  }
}
