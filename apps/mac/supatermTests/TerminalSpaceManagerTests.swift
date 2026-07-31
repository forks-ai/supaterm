import Foundation
import SupaTheme
import Testing

@testable import supaterm

@MainActor
struct TerminalSpaceManagerTests {
  @Test
  func ownsOnlyItsFixedSpace() {
    let space = TerminalSpaceItem(name: "A")
    let manager = TerminalSpaceManager(space: space)
    let otherSpaceID = TerminalSpaceID()

    #expect(manager.spaces == [space])
    #expect(manager.selectedSpaceID == space.id)
    #expect(manager.tabManager(for: otherSpaceID) == nil)
    #expect(manager.tabs(in: otherSpaceID).isEmpty)
  }

  @Test
  func catalogUpdatesRenameWithoutChangingOwnershipOrTabs() {
    let space = TerminalSpaceItem(name: "A")
    let manager = TerminalSpaceManager(space: space)
    let tabID = manager.tabManager.createTab(title: "Terminal 1")
    let updatedCatalog = TerminalSpaceCatalog(
      defaultSelectedSpaceID: space.id,
      spaces: [TerminalSpaceItem(id: space.id, name: "Renamed", color: .blue)]
    )
    manager.applyCatalog(updatedCatalog)

    #expect(manager.spaces.map(\.name) == ["Renamed"])
    #expect(manager.spaces.map(\.color) == [.blue])
    #expect(manager.selectedSpaceID == space.id)
    #expect(manager.tabs.map(\.id) == [tabID].compactMap { $0 })
  }

  @Test
  func spaceAtIndexExposesOnlyTheOwnedSpace() {
    let space = TerminalSpaceItem(name: "A")
    let manager = TerminalSpaceManager(space: space)

    #expect(manager.space(at: 1) == space)
    #expect(manager.space(at: 2) == nil)
  }
}
