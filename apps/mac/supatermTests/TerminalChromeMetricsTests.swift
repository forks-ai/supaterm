import CoreGraphics
import Testing

@testable import supaterm

struct TerminalChromeMetricsTests {
  @Test
  func matchesReferenceCornerRadii() {
    #expect(TerminalChromeMetrics.paneCornerRadius == 12)
    #expect(TerminalSidebarLayout.tabRowCornerRadius == 10)
  }
}
