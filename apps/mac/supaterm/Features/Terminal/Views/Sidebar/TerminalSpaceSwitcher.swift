import ComposableArchitecture
import SupaTheme
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
}

struct TerminalWindowHeader: View {
  let store: StoreOf<TerminalWindowFeature>
  let palette: Palette
  let terminal: TerminalHostState

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      WindowTrafficLights()
      TerminalSpaceSwitcher(
        store: store,
        palette: palette,
        spaces: terminal.availableSpaces,
        selectedSpaceID: terminal.selectedSpaceID
      )
      .padding(.top, 10)
    }
    .fixedSize()
  }
}

struct TerminalSpaceSwitcher: View {
  let store: StoreOf<TerminalWindowFeature>
  let palette: Palette
  let spaces: [TerminalSpaceItem]
  let selectedSpaceID: TerminalSpaceID?

  var body: some View {
    if let presentation = TerminalSpaceSwitcherPresentation(
      spaces: spaces,
      selectedSpaceID: selectedSpaceID
    ) {
      Menu {
        ForEach(spaces) { space in
          Button {
            _ = store.send(.selectSpaceButtonTapped(space.id))
          } label: {
            if space.id == selectedSpaceID {
              Label(space.name, systemImage: "checkmark")
            } else {
              Text(space.name)
            }
          }
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
        HStack(spacing: 6) {
          Text(
            TerminalSidebarLayout.spaceMonogram(
              for: presentation.selectedSpace.name,
              fallbackIndex: spaces.firstIndex(of: presentation.selectedSpace) ?? 0
            )
          )
          .font(.system(size: 11, weight: .semibold, design: .rounded))
          .frame(width: 20, height: 20)
          .background(palette.secondaryText.opacity(0.14), in: .circle)

          Text(presentation.selectedSpace.name)
            .font(.system(size: 12, weight: .medium))
            .lineLimit(1)

          Image(systemName: "chevron.down")
            .font(.system(size: 8, weight: .semibold))
            .foregroundStyle(palette.secondaryText)
            .accessibilityHidden(true)
        }
        .foregroundStyle(palette.primaryText)
        .padding(.horizontal, 8)
        .frame(height: 28)
        .background(palette.secondaryText.opacity(0.1), in: .rect(cornerRadius: 7))
      }
      .menuStyle(.button)
      .buttonStyle(.plain)
      .menuIndicator(.hidden)
      .fixedSize()
      .accessibilityLabel("Space \(presentation.selectedSpace.name)")
      .accessibilityIdentifier("titlebar.space-switcher")
      .help("Switch Space")
    }
  }
}
