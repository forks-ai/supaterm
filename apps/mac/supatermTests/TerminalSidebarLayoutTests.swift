import CoreGraphics
import Testing

@testable import supaterm

struct TerminalSidebarLayoutTests {
  @Test
  func firstVisibleSectionClearsTrafficLightsAndSelectionGlow() {
    let trafficLightBottom =
      WindowTrafficLightMetrics.edgePadding + WindowTrafficLightMetrics.buttonSize
    let selectionGlowTop =
      TerminalSidebarLayout.firstVisibleSectionTopInset
      - SelectableRowShadowMetrics.visualOutset

    #expect(selectionGlowTop - trafficLightBottom == 4)
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
