import Foundation
import Observation

@MainActor
@Observable
final class TerminalSpaceManager {
  private(set) var space: TerminalSpaceItem
  let tabManager = TerminalTabManager()

  init(space: TerminalSpaceItem) {
    self.space = space
  }

  var spaces: [TerminalSpaceItem] {
    [space]
  }

  var selectedSpaceID: TerminalSpaceID? {
    space.id
  }

  var tabs: [TerminalTabItem] {
    tabManager.tabs
  }

  var rootItems: [TerminalTabRootItem] {
    tabManager.rootItems
  }

  var visibleTabs: [TerminalTabItem] {
    tabManager.visibleTabs
  }

  var selectedTabID: TerminalTabID? {
    tabManager.selectedTabId
  }

  func applyCatalog(_ catalog: TerminalSpaceCatalog) {
    let resolvedCatalog = Self.sanitizedCatalog(catalog)
    if let persistedSpace = resolvedCatalog.spaces.first(where: { $0.id == space.id }) {
      space.name = persistedSpace.name
      space.color = persistedSpace.color
    }
  }

  func tabManager(for spaceID: TerminalSpaceID) -> TerminalTabManager? {
    spaceID == space.id ? tabManager : nil
  }

  func space(for tabID: TerminalTabID) -> TerminalSpaceItem? {
    tabManager.tabs.contains(where: { $0.id == tabID }) ? space : nil
  }

  func space(for groupID: TerminalTabGroupID) -> TerminalSpaceItem? {
    tabManager.group(for: groupID) == nil ? nil : space
  }

  func space(for rootItemID: TerminalTabRootItemID) -> TerminalSpaceItem? {
    switch rootItemID {
    case .tab(let tabID):
      return space(for: tabID)
    case .group(let groupID):
      return space(for: groupID)
    }
  }

  func tabs(in spaceID: TerminalSpaceID) -> [TerminalTabItem] {
    spaceID == space.id ? tabManager.tabs : []
  }

  func rootItems(in spaceID: TerminalSpaceID) -> [TerminalTabRootItem] {
    spaceID == space.id ? tabManager.rootItems : []
  }

  func space(at index: Int) -> TerminalSpaceItem? {
    index == 1 ? space : nil
  }

  func selectedTabID(in spaceID: TerminalSpaceID) -> TerminalTabID? {
    spaceID == space.id ? tabManager.selectedTabId : nil
  }

  func spaceIndex(for spaceID: TerminalSpaceID) -> Int? {
    spaceID == space.id ? 1 : nil
  }

  func tab(for tabID: TerminalTabID) -> TerminalTabItem? {
    tabManager.tabs.first(where: { $0.id == tabID })
  }

  @discardableResult
  func restoreRootItems(
    _ rootItems: [TerminalTabRootItem],
    selectedTabID: TerminalTabID?,
    in spaceID: TerminalSpaceID
  ) -> Bool {
    guard spaceID == space.id else { return false }
    tabManager.restoreRootItems(rootItems, selectedTabID: selectedTabID)
    return true
  }

  private static func sanitizedCatalog(
    _ catalog: TerminalSpaceCatalog
  ) -> TerminalSpaceCatalog {
    TerminalSpaceCatalog.sanitized(catalog)
  }
}
