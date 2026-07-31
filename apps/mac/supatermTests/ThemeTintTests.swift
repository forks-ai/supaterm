import SupaTheme
import SupatermCLIShared
import Testing

@testable import supaterm

struct ThemeTintTests {
  @Test
  func terminalColorsMatchSocketColors() {
    for color in ThemeTint.allCases {
      #expect(color.socketColor.rawValue == color.rawValue)
    }
  }

  @Test
  func socketColorsMatchTerminalColors() {
    for color in SupatermTabGroupColor.allCases {
      #expect(ThemeTint(socketColor: color).rawValue == color.rawValue)
    }
  }
}
