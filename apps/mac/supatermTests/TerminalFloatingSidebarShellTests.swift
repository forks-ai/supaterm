import CoreGraphics
import Testing

@testable import supaterm

struct TerminalFloatingSidebarShellTests {
  @Test
  func usesOnePointBorder() {
    #expect(TerminalFloatingSidebarShellMetrics.borderWidth == 1)
  }

  @Test
  func preservesCurrentShellGeometry() {
    #expect(TerminalFloatingSidebarShellMetrics.contentInset == TerminalChromeMetrics.paneInset)
    #expect(TerminalFloatingSidebarShellMetrics.cornerRadius == 16)
    #expect(TerminalFloatingSidebarShellMetrics.shadowRadius == 16)
    #expect(TerminalFloatingSidebarShellMetrics.shadowYOffset == 6)
  }
}
