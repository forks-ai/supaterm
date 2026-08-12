import AppKit
import SwiftUI
import Testing

@testable import supaterm

struct TerminalSidebarHoverCardTests {
  @Test @MainActor
  func shortResponseUsesItsContentHeight() {
    let content = TerminalSidebarHoverCardContent(
      tabTitle: "Ready",
      response: TerminalHostState.TabAgentResponse(
        agent: AgentDetectionAgentIdentity(id: "agent", displayName: "Agent"),
        text: "Hello, khoi."
      )
    )
    let controller = NSHostingController(
      rootView: TerminalSidebarHoverCardView(content: content)
    )

    let size = controller.sizeThatFits(in: CGSize(width: 320, height: 800))

    #expect(size.height < 180)
  }

  @Test @MainActor
  func longResponseUsesMaximumResponseHeight() {
    let response = AttributedString(
      String(repeating: "A long response line that wraps inside the hover card.\n", count: 100)
    )

    #expect(
      TerminalSidebarHoverCardMetrics.responseHeight(for: response)
        == TerminalSidebarHoverCardMetrics.maximumResponseHeight
    )
  }

  @Test
  func placesCardBesideAndCenteredOnSource() {
    let frame = TerminalSidebarHoverCardGeometry.frame(
      sourceFrame: CGRect(x: 100, y: 200, width: 180, height: 40),
      cardSize: CGSize(width: 320, height: 180),
      visibleFrame: CGRect(x: 0, y: 0, width: 1_200, height: 800)
    )

    #expect(frame.origin.x == 284)
    #expect(frame.midY == 220)
  }

  @Test
  func clampsCardToVisibleScreenInsets() {
    let frame = TerminalSidebarHoverCardGeometry.frame(
      sourceFrame: CGRect(x: 900, y: 760, width: 180, height: 40),
      cardSize: CGSize(width: 320, height: 180),
      visibleFrame: CGRect(x: 0, y: 0, width: 1_200, height: 800)
    )

    #expect(frame.maxX == 1_192)
    #expect(frame.maxY == 792)
  }

  @Test
  func corridorConnectsSourceAndCardWithoutCoveringOutsidePoints() {
    let corridor = TerminalSidebarHoverCorridor(
      sourceFrame: CGRect(x: 100, y: 200, width: 180, height: 40),
      cardFrame: CGRect(x: 284, y: 130, width: 320, height: 180)
    )

    #expect(corridor.contains(CGPoint(x: 282, y: 220)))
    #expect(corridor.contains(CGPoint(x: 400, y: 300)))
    #expect(!corridor.contains(CGPoint(x: 50, y: 100)))
    #expect(!corridor.contains(CGPoint(x: 400, y: 400)))
  }
}
