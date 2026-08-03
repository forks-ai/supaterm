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
      AnyView(TerminalWindowHeaderSnapshotFixture(appearance: appearance))
    },
    scenario(
      "space-switcher-hover",
      group: "Terminal Chrome",
      title: "Window Space switcher hover",
      size: CGSize(width: 240, height: 48)
    ) { appearance in
      AnyView(SpaceSwitcherHoverSnapshotFixture(appearance: appearance))
    },
    scenario(
      "detail-pane",
      group: "Terminal Chrome",
      title: "Sidebar and detail pane",
      size: CGSize(width: 760, height: 420)
    ) { appearance in
      AnyView(TerminalChromeSnapshotFixture(appearance: appearance))
    },
    scenario(
      "floating-sidebar",
      group: "Terminal Chrome",
      title: "Floating sidebar",
      size: CGSize(width: 760, height: 420)
    ) { appearance in
      AnyView(FloatingSidebarSnapshotFixture(appearance: appearance))
    },
  ]
}

@MainActor
private struct TerminalWindowHeaderSnapshotFixture: View {
  let appearance: SnapshotAppearance

  private var palette: Palette {
    Palette(colorScheme: appearance.colorScheme)
  }

  var body: some View {
    TerminalWindowHeader(
      store: SidebarChromeSnapshotContext.windowStore(),
      palette: palette,
      terminal: SidebarChromeSnapshotContext.terminal
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(palette.windowBackgroundTint)
    .environment(\.colorScheme, appearance.colorScheme)
  }
}

private struct SpaceSwitcherHoverSnapshotFixture: View {
  let appearance: SnapshotAppearance

  private var palette: Palette {
    Palette(colorScheme: appearance.colorScheme)
  }

  var body: some View {
    TerminalSpaceSwitcherLabel(
      palette: palette,
      name: "supaterm",
      isHovered: true
    )
    .padding(10)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    .background(palette.windowBackgroundTint)
    .environment(\.colorScheme, appearance.colorScheme)
  }
}

@MainActor
private struct TerminalChromeSnapshotFixture: View {
  let appearance: SnapshotAppearance

  private var palette: Palette {
    Palette(
      colorScheme: appearance.colorScheme,
      tint: SidebarChromeSnapshotContext.selectedGroupTerminal.displayedSpace.color
    )
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
      sidebarWidth: 228,
      sidebarResizeState: nil,
      onResizeInput: { _ in },
      dismissReleaseAnnouncement: {}
    )
    .environment(SidebarChromeSnapshotContext.commandHold)
    .environment(SidebarChromeSnapshotContext.ghosttyShortcuts)
    .background(ChromeBackgroundView(palette: palette))
  }
}

@MainActor
private struct FloatingSidebarSnapshotFixture: View {
  let appearance: SnapshotAppearance

  private var palette: Palette {
    Palette(
      colorScheme: appearance.colorScheme,
      tint: SidebarChromeSnapshotContext.selectedGroupTerminal.displayedSpace.color
    )
  }

  var body: some View {
    FloatingSidebarOverlay(
      store: SidebarChromeSnapshotContext.windowStore(),
      updateStore: SidebarChromeSnapshotContext.updateStore(),
      releaseAnnouncement: nil,
      palette: palette,
      terminal: SidebarChromeSnapshotContext.selectedGroupTerminal,
      totalWidth: 760,
      sidebarWidth: 228,
      sidebarResizeState: nil,
      isVisible: .constant(true),
      onResizeInput: { _ in },
      dismissReleaseAnnouncement: {}
    )
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    .environment(SidebarChromeSnapshotContext.commandHold)
    .environment(SidebarChromeSnapshotContext.ghosttyShortcuts)
    .background(ChromeBackgroundView(palette: palette))
    .environment(\.colorScheme, appearance.colorScheme)
  }
}
