import AppKit
import Testing

@testable import supaterm

@MainActor
struct WindowBackgroundEffectViewTests {
  @Test
  func usesBehindWindowMaterialThatFollowsWindowActivity() {
    let view = NSVisualEffectView()

    WindowBackgroundEffectView.configure(view)

    #expect(view.material == .underWindowBackground)
    #expect(view.blendingMode == .behindWindow)
    #expect(view.state == .followsWindowActiveState)
    #expect(view.isEmphasized)
  }
}
