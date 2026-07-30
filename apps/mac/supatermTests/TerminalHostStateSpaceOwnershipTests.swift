import ComposableArchitecture
import Sharing
import Testing

@testable import supaterm

@MainActor
struct TerminalHostStateSpaceOwnershipTests {
  @Test
  func hostOwnsOneFixedSpace() async {
    await withDependencies {
      $0.defaultFileStorage = .inMemory
    } operation: {
      let spaces = [TerminalSpaceItem(name: "A"), TerminalSpaceItem(name: "B")]
      @Shared(.terminalSpaceCatalog) var catalog = TerminalSpaceCatalog.default
      $catalog.withLock {
        $0 = TerminalSpaceCatalog(defaultSelectedSpaceID: spaces[1].id, spaces: spaces)
      }

      let host = TerminalHostState(managesTerminalSurfaces: false, spaceID: spaces[0].id)

      #expect(host.spaces == [spaces[0]])
      #expect(host.selectedSpaceID == spaces[0].id)
      #expect(host.availableSpaces == spaces)

      $catalog.withLock {
        $0.defaultSelectedSpaceID = spaces[1].id
        $0.spaces[0].name = "Renamed"
      }
      for _ in 0..<5 {
        await Task.yield()
      }

      #expect(host.spaces.map(\.name) == ["Renamed"])
      #expect(host.selectedSpaceID == spaces[0].id)
      #expect(host.availableSpaces.map(\.name) == ["Renamed", "B"])
    }
  }

  @Test
  func spaceCommandsLeaveOwnershipToTheWindowRegistry() {
    withDependencies {
      $0.defaultFileStorage = .inMemory
    } operation: {
      let host = TerminalHostState(managesTerminalSurfaces: false)
      let otherSpaceID = TerminalSpaceID()
      var actions: [TerminalHostState.SpaceAction] = []
      host.onSpaceAction = { actions.append($0) }

      host.handleCommand(.createSpace(name: "Build"))
      host.handleCommand(.selectSpace(otherSpaceID))
      host.handleCommand(.renameSpace(otherSpaceID, "Shell"))
      host.handleCommand(.nextSpace)
      host.handleCommand(.previousSpace)
      host.handleCommand(.deleteSpace(otherSpaceID))

      #expect(
        actions == [
          .create("Build"),
          .select(otherSpaceID),
          .rename(otherSpaceID, "Shell"),
          .next,
          .previous,
          .delete(otherSpaceID),
        ]
      )
      #expect(host.selectedSpaceID != otherSpaceID)
    }
  }
}
