import ComposableArchitecture
import Sharing
import SupaTheme
import SupatermCLIShared
import SwiftUI

struct TerminalSpaceSwitcherPresentation: Equatable {
  let selectedSpace: TerminalSpaceItem
  let canDelete: Bool

  init?(spaces: [TerminalSpaceItem], selectedSpaceID: TerminalSpaceID?) {
    guard let selectedSpace = spaces.first(where: { $0.id == selectedSpaceID }) else {
      return nil
    }
    self.selectedSpace = selectedSpace
    self.canDelete = spaces.count > 1
  }

  static func shortcutBinding(
    forSpaceAt index: Int,
    overrides: [SupatermShortcutID: SupatermShortcutOverride]
  ) -> SupatermShortcutBinding? {
    let slot = index + 1
    guard (1...10).contains(slot) else { return nil }
    return SupatermShortcuts.binding(for: .selectSpace(slot), overrides: overrides)
  }
}

enum TerminalWindowHeaderMetrics {
  static let spacing: CGFloat = 10
  static let switcherHeight: CGFloat = 28

  static var switcherTopPadding: CGFloat {
    WindowTrafficLightMetrics.edgePadding
      + WindowTrafficLightMetrics.buttonSize / 2
      - switcherHeight / 2
  }
}

struct TerminalWindowHeader: View {
  let store: StoreOf<TerminalWindowFeature>
  let palette: Palette
  let terminal: TerminalHostState

  var body: some View {
    HStack(alignment: .top, spacing: TerminalWindowHeaderMetrics.spacing) {
      WindowTrafficLights()
      TerminalSpaceSwitcher(
        store: store,
        palette: palette,
        spaces: terminal.availableSpaces,
        selectedSpaceID: terminal.selectedSpaceID
      )
      .padding(.top, TerminalWindowHeaderMetrics.switcherTopPadding)
    }
    .fixedSize()
  }
}

struct TerminalSpaceSwitcher: View {
  let store: StoreOf<TerminalWindowFeature>
  let palette: Palette
  let spaces: [TerminalSpaceItem]
  let selectedSpaceID: TerminalSpaceID?

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Shared(.supatermSettings) private var supatermSettings = .default
  @State private var isHovered = false

  var body: some View {
    if let presentation = TerminalSpaceSwitcherPresentation(
      spaces: spaces,
      selectedSpaceID: selectedSpaceID
    ) {
      Menu {
        ForEach(Array(spaces.enumerated()), id: \.element.id) { index, space in
          Button {
            _ = store.send(.selectSpaceButtonTapped(space.id))
          } label: {
            if space.id == selectedSpaceID {
              Label(space.name, systemImage: "checkmark")
            } else {
              Text(space.name)
            }
          }
          .supatermKeyboardShortcut(
            TerminalSpaceSwitcherPresentation.shortcutBinding(
              forSpaceAt: index,
              overrides: supatermSettings.shortcutOverrides
            )?.keyboardShortcut
          )
        }

        Divider()

        Button {
          _ = store.send(.spaceCreateButtonTapped)
        } label: {
          Label("New Space", systemImage: "plus")
        }

        Button {
          _ = store.send(.spaceRenameRequested(presentation.selectedSpace))
        } label: {
          Label("Rename Space", systemImage: "textformat")
        }

        Button(role: .destructive) {
          _ = store.send(.spaceDeleteRequested(presentation.selectedSpace))
        } label: {
          Label("Delete Space", systemImage: "trash")
        }
        .disabled(!presentation.canDelete)
      } label: {
        TerminalSpaceSwitcherLabel(
          palette: palette,
          name: presentation.selectedSpace.name,
          color: presentation.selectedSpace.color,
          isHovered: isHovered
        )
      }
      .menuStyle(.button)
      .buttonStyle(.plain)
      .menuIndicator(.hidden)
      .fixedSize()
      .onHover { hovering in
        TerminalMotion.animate(.easeInOut(duration: 0.1), reduceMotion: reduceMotion) {
          isHovered = hovering
        }
      }
      .accessibilityLabel("Space \(presentation.selectedSpace.name)")
      .accessibilityIdentifier("titlebar.space-switcher")
      .help("Switch Space")
    }
  }
}

struct TerminalSpaceSwitcherLabel: View {
  let palette: Palette
  let name: String
  let color: ThemeTint
  let isHovered: Bool

  var body: some View {
    HStack(spacing: 6) {
      if color != .neutral {
        Circle()
          .fill(color.sidebarColor(palette: palette))
          .frame(width: 8, height: 8)
      }
      Text(name)
        .font(.system(size: 12, weight: .medium))
        .lineLimit(1)
        .foregroundStyle(palette.primaryText)
    }
    .padding(.horizontal, 8)
    .frame(height: TerminalWindowHeaderMetrics.switcherHeight)
    .background(
      isHovered ? palette.secondaryText.opacity(0.1) : .clear,
      in: .rect(cornerRadius: 7)
    )
  }
}
