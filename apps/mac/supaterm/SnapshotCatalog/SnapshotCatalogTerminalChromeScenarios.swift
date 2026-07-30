import SupaTheme
import SwiftUI

extension SnapshotCatalog {
  static let terminalChromeScenarios: [SnapshotScenario] = [
    scenario(
      "space-switcher",
      group: "Terminal Chrome",
      title: "Window Space switcher",
      size: CGSize(width: 360, height: 64)
    ) { appearance in
      AnyView(TerminalSpaceSwitcherSnapshotFixture(appearance: appearance))
    },
    scenario(
      "detail-pane",
      group: "Terminal Chrome",
      title: "Sidebar and detail pane",
      size: CGSize(width: 760, height: 420)
    ) { appearance in
      AnyView(TerminalChromeSnapshotFixture(appearance: appearance))
    },
  ]
}

@MainActor
private struct TerminalSpaceSwitcherSnapshotFixture: View {
  let appearance: SnapshotAppearance

  private var palette: Palette {
    Palette(colorScheme: appearance.colorScheme)
  }

  var body: some View {
    TerminalSpaceSwitcher(
      store: SidebarChromeSnapshotContext.windowStore(),
      palette: palette,
      spaces: SidebarChromeSnapshotContext.terminal.availableSpaces,
      selectedSpaceID: SidebarChromeSnapshotContext.terminal.selectedSpaceID
    )
    .padding(.top, 10)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(palette.windowBackgroundTint)
    .environment(\.colorScheme, appearance.colorScheme)
  }
}

@MainActor
private struct TerminalChromeSnapshotFixture: View {
  let appearance: SnapshotAppearance

  @State private var sidebarFraction: CGFloat = 0.36

  private var palette: Palette {
    Palette(colorScheme: appearance.colorScheme)
  }

  var body: some View {
    TerminalSplitView(
      store: SidebarChromeSnapshotContext.windowStore(),
      updateStore: SidebarChromeSnapshotContext.updateStore(),
      releaseAnnouncement: nil,
      palette: palette,
      terminal: SidebarChromeSnapshotContext.selectedGroupTerminal,
      totalWidth: 760,
      isSidebarCollapsed: false,
      sidebarFraction: $sidebarFraction,
      minFraction: 0.1,
      maxFraction: 0.5,
      onHide: {},
      dismissReleaseAnnouncement: {}
    )
    .environment(SidebarChromeSnapshotContext.commandHold)
    .environment(SidebarChromeSnapshotContext.ghosttyShortcuts)
    .background(ChromeBackgroundView(palette: palette))
  }
}
