import AppKit
import Testing

@testable import supaterm

struct GhosttySurfaceHoverLinkOverlayTests {
  @Test
  func bannerMovesAwayFromPointerAtLeadingEdge() {
    #expect(
      GhosttySurfaceHoverLinkPresentation.placement(pointerIsNearLeadingBanner: false)
        == .leading
    )
    #expect(
      GhosttySurfaceHoverLinkPresentation.placement(pointerIsNearLeadingBanner: true)
        == .trailing
    )
  }

  @Test
  func bannerCornersRemainDisjointInNarrowPanes() {
    let containerWidth: CGFloat = 240
    let maximumBannerWidth = GhosttySurfaceHoverLinkPresentation.maximumBannerWidth(
      containerWidth: containerWidth
    )

    #expect(maximumBannerWidth * 2 < containerWidth)
  }

  @Test
  func hoverTrackingNeverAcceptsTerminalInput() {
    let view = GhosttySurfaceHoverTrackingView.TrackingView(onHoverChange: { _ in })
    view.frame = CGRect(x: 0, y: 0, width: 100, height: 30)

    #expect(view.hitTest(NSPoint(x: 50, y: 15)) == nil)
  }
}
