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
  func spaceSwitcherResolvesSelectedSpace() throws {
    let first = TerminalSpaceItem(id: TerminalSpaceID(), name: "First")
    let second = TerminalSpaceItem(id: TerminalSpaceID(), name: "Second")

    let presentation = try #require(
      TerminalSpaceSwitcherPresentation(
        spaces: [first, second],
        selectedSpaceID: second.id
      )
    )

    #expect(presentation.selectedSpace == second)
    #expect(presentation.canDelete)
  }

  @Test
  func spaceSwitcherAlignsWithTrafficLightCenters() {
    let trafficLightCenter =
      WindowTrafficLightMetrics.edgePadding + WindowTrafficLightMetrics.buttonSize / 2
    let switcherCenter =
      TerminalWindowHeaderMetrics.switcherTopPadding
      + TerminalWindowHeaderMetrics.switcherHeight / 2

    #expect(switcherCenter == trafficLightCenter)
  }

  @Test
  func spaceSwitcherUsesEffectiveSpaceShortcuts() {
    let bindings = (0..<4).map {
      TerminalSpaceSwitcherPresentation.shortcutBinding(
        forSpaceAt: $0,
        overrides: [:]
      )?.display
    }

    #expect(bindings == ["⌃1", "⌃2", "⌃3", "⌃4"])
  }

  @Test
  func spaceSwitcherOmitsDisabledAndOutOfRangeShortcuts() {
    #expect(
      TerminalSpaceSwitcherPresentation.shortcutBinding(
        forSpaceAt: 0,
        overrides: [.selectSpace(1): .disabled]
      ) == nil
    )
    #expect(
      TerminalSpaceSwitcherPresentation.shortcutBinding(
        forSpaceAt: 10,
        overrides: [:]
      ) == nil
    )
  }

  @Test
  func spaceSwitcherDisablesDeletingOnlySpace() throws {
    let space = TerminalSpaceItem(id: TerminalSpaceID(), name: "Only")

    let presentation = try #require(
      TerminalSpaceSwitcherPresentation(
        spaces: [space],
        selectedSpaceID: space.id
      )
    )

    #expect(!presentation.canDelete)
  }

  @Test
  func spaceSwitcherRejectsMissingSelection() {
    let space = TerminalSpaceItem(id: TerminalSpaceID(), name: "Only")

    #expect(
      TerminalSpaceSwitcherPresentation(
        spaces: [space],
        selectedSpaceID: TerminalSpaceID()
      ) == nil
    )
  }
}
