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
}
