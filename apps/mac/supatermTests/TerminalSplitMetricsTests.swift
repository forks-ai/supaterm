import CoreGraphics
import Testing

@testable import supaterm

struct TerminalSplitMetricsTests {
  @Test
  func defaultWidthTracksWindowWidth() {
    #expect(TerminalSidebarWidthPolicy.defaultWidth(for: 1_080) == 216)
    #expect(TerminalSidebarWidthPolicy.defaultWidth(for: 1_440) == 288)
    #expect(TerminalSidebarWidthPolicy.defaultWidth(for: 1_760) == 352)
  }

  @Test
  func resolvedWidthUsesSavedPointsWithinBounds() {
    #expect(TerminalSidebarWidthPolicy.resolvedWidth(preferredWidth: 320, totalWidth: 1_440) == 320)
    #expect(TerminalSidebarWidthPolicy.resolvedWidth(preferredWidth: 600, totalWidth: 1_440) == 432)
    #expect(TerminalSidebarWidthPolicy.resolvedWidth(preferredWidth: 320, totalWidth: 250) == 75)
  }

  @Test
  func interactionStripSitsInTrailingEightPoints() {
    #expect(TerminalSidebarWidthPolicy.interactionStripWidth == 8)
    #expect(TerminalSplitMetrics.resizeStripOffset(for: 320) == 312)
    #expect(TerminalSplitMetrics.resizeStripOffset(for: 4) == 0)
  }

  @Test
  func dragElasticityRemainsControlledBeyondWidthBounds() {
    let lowerBound = TerminalSidebarResizeState(startingWidth: 144, delta: -48)
    let upperBound = TerminalSidebarResizeState(startingWidth: 432, delta: 48)

    #expect(
      TerminalSidebarWidthPolicy.displayedWidth(
        preferredWidth: 144,
        resizeState: lowerBound,
        totalWidth: 1_440
      ) == 120
    )
    #expect(
      TerminalSidebarWidthPolicy.displayedWidth(
        preferredWidth: 432,
        resizeState: upperBound,
        totalWidth: 1_440
      ) == 456
    )
    #expect(
      TerminalSidebarWidthPolicy.displayedWidth(
        preferredWidth: 144,
        resizeState: TerminalSidebarResizeState(startingWidth: 144, delta: -10_000),
        totalWidth: 1_440
      ) > 96
    )
  }

  @Test
  func releaseCollapsesOnlyBelowMinimum() {
    let atMinimum = TerminalSidebarResizeState(startingWidth: 300, delta: -156)
    let belowMinimum = TerminalSidebarResizeState(startingWidth: 300, delta: -157)

    #expect(!TerminalSidebarWidthPolicy.shouldCollapse(resizeState: atMinimum, totalWidth: 1_440))
    #expect(TerminalSidebarWidthPolicy.shouldCollapse(resizeState: belowMinimum, totalWidth: 1_440))
    #expect(TerminalSidebarWidthPolicy.settledWidth(for: atMinimum, totalWidth: 1_440) == 144)
  }

  @Test
  func elasticReleaseSettlesAtBound() {
    let upper = TerminalSidebarResizeState(startingWidth: 432, delta: 100)

    #expect(
      TerminalSidebarWidthPolicy.displayedWidth(
        preferredWidth: 432,
        resizeState: upper,
        totalWidth: 1_440
      ) > 432
    )
    #expect(TerminalSidebarWidthPolicy.settledWidth(for: upper, totalWidth: 1_440) == 432)
  }
}
