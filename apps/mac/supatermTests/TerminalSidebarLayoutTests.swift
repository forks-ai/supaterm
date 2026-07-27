import AppKit
import CoreGraphics
import Testing

@testable import supaterm

@MainActor
struct TerminalSidebarLayoutTests {
  @Test
  func scrollViewportClearsTrafficLightsWithoutContentInsets() throws {
    let controller = TerminalSidebarListController()
    controller.view.frame = CGRect(x: 0, y: 0, width: 280, height: 160)
    controller.view.layoutSubtreeIfNeeded()
    let scrollView = try #require(
      controller.view.subviews.compactMap { $0 as? TerminalSidebarScrollView }.first
    )
    let viewportTopInset = controller.view.bounds.maxY - scrollView.frame.maxY
    let trafficLightBottom =
      WindowTrafficLightMetrics.edgePadding + WindowTrafficLightMetrics.buttonSize

    #expect(viewportTopInset - trafficLightBottom == TerminalSidebarLayout.trafficLightGap)
    #expect(!scrollView.automaticallyAdjustsContentInsets)
    #expect(scrollView.contentInsets.top == 0)
    #expect(scrollView.contentInsets.bottom == 0)
  }

  @Test
  func topEntriesKeepTheirInkInsideTheDocument() throws {
    let root = TerminalTabID()
    let child = TerminalTabID()
    let groupID = TerminalTabGroupID()
    let rootFirst = TerminalSidebarTestFixture.outline(
      roots: [
        TerminalSidebarOutline.Root(content: .tab(root), isPinned: false),
        TerminalSidebarOutline.Root(
          content: .group(groupID, .yellow, .automatic, [child]),
          isPinned: false
        ),
      ],
      revision: 1
    )
    let groupFirst = TerminalSidebarTestFixture.outline(
      roots: [
        TerminalSidebarOutline.Root(
          content: .group(groupID, .yellow, .automatic, [child]),
          isPinned: false
        )
      ],
      revision: 1
    )
    let rootFirstPlan = TerminalSidebarTestFixture.layoutPlan(outline: rootFirst)
    let groupFirstPlan = TerminalSidebarTestFixture.layoutPlan(outline: groupFirst)
    let rootFrame = try #require(rootFirstPlan.items.first { $0.id == .tab(root) }?.frame)
    let groupFrame = try #require(groupFirstPlan.groups.first?.frame)

    #expect(TerminalSidebarSelectionGlowView.visualFrame(for: rootFrame).minY >= 0)
    #expect(groupFrame.minY == SelectableRowShadowMetrics.visualOutset)
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
