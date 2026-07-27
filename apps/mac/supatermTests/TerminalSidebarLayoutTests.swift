import AppKit
import CoreGraphics
import Testing

@testable import supaterm

@MainActor
struct TerminalSidebarLayoutTests {
  @Test
  func scrollViewportClearsTrafficLights() throws {
    let controller = TerminalSidebarListController()
    controller.view.frame = CGRect(x: 0, y: 0, width: 280, height: 160)
    controller.view.layoutSubtreeIfNeeded()
    let scrollView = try #require(
      controller.view.subviews.compactMap { $0 as? TerminalSidebarScrollView }.first
    )
    let viewportTopInset = controller.view.bounds.maxY - scrollView.frame.maxY
    let trafficLightBottom =
      WindowTrafficLightMetrics.edgePadding + WindowTrafficLightMetrics.buttonSize

    #expect(viewportTopInset - trafficLightBottom == 4)
  }

  @Test
  func firstVisibleSectionPreservesSelectionGlow() {
    let selectionGlowTop =
      TerminalSidebarLayout.firstVisibleSectionTopInset
      + TerminalSidebarLayoutPlan.initialY
      - SelectableRowShadowMetrics.visualOutset

    #expect(selectionGlowTop == TerminalSidebarLayout.groupSurfaceVerticalOverflow)
  }

  @Test
  func firstVisibleGroupPreservesItsSurfaceTop() throws {
    let child = TerminalTabID()
    let groupID = TerminalTabGroupID()
    let outline = TerminalSidebarTestFixture.outline(
      roots: [
        TerminalSidebarOutline.Root(
          content: .group(groupID, .yellow, .automatic, [child]),
          isPinned: false
        )
      ],
      revision: 1
    )
    let plan = TerminalSidebarTestFixture.layoutPlan(outline: outline)
    let groupFrame = try #require(plan.groups.first?.frame)
    let groupSurfaceTop =
      TerminalSidebarLayout.firstVisibleSectionTopInset + groupFrame.minY

    #expect(groupSurfaceTop == SelectableRowShadowMetrics.visualOutset)
  }

  @Test
  func spaceMonogramUsesFirstNonWhitespaceCharacter() {
    #expect(TerminalSidebarLayout.spaceMonogram(for: "  shell", fallbackIndex: 2) == "S")
  }

  @Test
  func spaceMonogramPreservesLeadingEmoji() {
    #expect(TerminalSidebarLayout.spaceMonogram(for: "  🚀 launch", fallbackIndex: 2) == "🚀")
  }

  @Test
  func spaceMonogramFallsBackToOrdinalForBlankName() {
    #expect(TerminalSidebarLayout.spaceMonogram(for: "   ", fallbackIndex: 2) == "3")
  }

  @Test
  func singleSpaceHidesSpaceList() {
    #expect(!TerminalSidebarLayout.showsSpaceList(spacesCount: 1))
  }

  @Test
  func multipleSpacesShowSpaceList() {
    #expect(TerminalSidebarLayout.showsSpaceList(spacesCount: 2))
  }
}
