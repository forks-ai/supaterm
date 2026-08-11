struct TerminalTabTopology: Equatable {
  struct AppliedMove {
    let deletedEmptyGroupIDs: [TerminalTabGroupID]
  }

  struct ExtractedItems {
    let childIDsByGroupID: [TerminalTabGroupID: [TerminalTabID]]
    let deletedEmptyGroupIDs: [TerminalTabGroupID]
    let groupsByID: [TerminalTabGroupID: TerminalTabGroup]
    let tabIDs: [TerminalTabID]
    let tabsByID: [TerminalTabID: TerminalTabItem]
  }

  struct MoveSource {
    let groupIDs: [TerminalTabGroupID]
  }

  var tabsByID: [TerminalTabID: TerminalTabItem] = [:]
  var groupsByID: [TerminalTabGroupID: TerminalTabGroup] = [:]
  var pinnedRootIDs: [TerminalTabRootItemID] = []
  var regularRootIDs: [TerminalTabRootItemID] = []
  var childIDsByGroupID: [TerminalTabGroupID: [TerminalTabID]] = [:]
  var revision: UInt64 = 0

  mutating func extract(_ itemIDs: [TerminalTabRootItemID]) throws -> ExtractedItems {
    let source = try moveSource(for: itemIDs)
    var extractedChildIDsByGroupID: [TerminalTabGroupID: [TerminalTabID]] = [:]
    var extractedGroupsByID: [TerminalTabGroupID: TerminalTabGroup] = [:]
    var extractedTabIDs: [TerminalTabID] = []
    var extractedTabsByID: [TerminalTabID: TerminalTabItem] = [:]

    for itemID in itemIDs {
      switch itemID {
      case .tab(let tabID):
        guard let tab = tabsByID[tabID] else {
          throw TerminalTabMoveError.itemNotFound(itemID)
        }
        extractedTabIDs.append(tabID)
        extractedTabsByID[tabID] = tab
        remove(itemID)
        tabsByID[tabID] = nil

      case .group(let groupID):
        guard let group = groupsByID[groupID] else {
          throw TerminalTabMoveError.itemNotFound(itemID)
        }
        let childIDs = childIDsByGroupID[groupID] ?? []
        extractedGroupsByID[groupID] = group
        extractedChildIDsByGroupID[groupID] = childIDs
        for tabID in childIDs {
          guard let tab = tabsByID[tabID] else {
            throw TerminalTabMoveError.itemNotFound(.tab(tabID))
          }
          extractedTabIDs.append(tabID)
          extractedTabsByID[tabID] = tab
          tabsByID[tabID] = nil
        }
        remove(itemID)
        groupsByID[groupID] = nil
        childIDsByGroupID[groupID] = nil
      }
    }

    let deletedEmptyGroupIDs = source.groupIDs.filter {
      deleteAutomaticGroupIfEmpty($0)
    }
    return ExtractedItems(
      childIDsByGroupID: extractedChildIDsByGroupID,
      deletedEmptyGroupIDs: deletedEmptyGroupIDs,
      groupsByID: extractedGroupsByID,
      tabIDs: extractedTabIDs,
      tabsByID: extractedTabsByID
    )
  }

  mutating func insert(
    _ itemIDs: [TerminalTabRootItemID],
    extracted: ExtractedItems,
    at destination: TerminalTabPlacement
  ) throws {
    try validateDestination(destination, for: itemIDs)
    for tabID in extracted.tabIDs {
      guard tabsByID[tabID] == nil else {
        throw TerminalTabTransferError.destinationContainsTab(tabID)
      }
    }
    for groupID in extracted.groupsByID.keys {
      guard groupsByID[groupID] == nil else {
        throw TerminalTabTransferError.destinationContainsGroup(groupID)
      }
    }

    for (tabID, tab) in extracted.tabsByID {
      tabsByID[tabID] = tab
    }
    for (groupID, group) in extracted.groupsByID {
      groupsByID[groupID] = group
      childIDsByGroupID[groupID] = extracted.childIDsByGroupID[groupID] ?? []
    }
    try insertMovedItems(itemIDs, at: destination)
  }

  mutating func apply(_ request: TerminalTabMoveRequest) throws -> AppliedMove {
    guard request.expectedTopologyRevision == revision else {
      throw TerminalTabMoveError.staleTopology(
        expected: request.expectedTopologyRevision,
        actual: revision
      )
    }
    let source = try moveSource(for: request.itemIDs)
    try validateDestination(request.destination, for: request.itemIDs)
    for itemID in request.itemIDs {
      remove(itemID)
    }
    var deletedEmptyGroupIDs: [TerminalTabGroupID] = []
    let destinationGroupID: TerminalTabGroupID? =
      switch request.destination {
      case .group(let groupID, _): groupID
      case .root: nil
      }
    for groupID in source.groupIDs
    where groupID != destinationGroupID && deleteAutomaticGroupIfEmpty(groupID) {
      deletedEmptyGroupIDs.append(groupID)
    }
    try insertMovedItems(request.itemIDs, at: request.destination)
    return AppliedMove(deletedEmptyGroupIDs: deletedEmptyGroupIDs)
  }

  func moveSource(for itemIDs: [TerminalTabRootItemID]) throws -> MoveSource {
    guard !itemIDs.isEmpty else { throw TerminalTabMoveError.emptyItems }
    let requestedGroupIDs = Set(
      itemIDs.compactMap { itemID -> TerminalTabGroupID? in
        guard case .group(let groupID) = itemID else { return nil }
        return groupID
      })
    for itemID in itemIDs {
      guard case .tab(let tabID) = itemID else { continue }
      guard
        case .group(let groupID, _) = location(of: itemID),
        requestedGroupIDs.contains(groupID)
      else { continue }
      throw TerminalTabMoveError.ancestorAndDescendant(groupID, tabID)
    }
    var seenIDs: Set<TerminalTabRootItemID> = []
    var sourceGroupIDs: [TerminalTabGroupID] = []
    for itemID in itemIDs {
      guard seenIDs.insert(itemID).inserted else {
        throw TerminalTabMoveError.duplicateItem(itemID)
      }
      guard let location = location(of: itemID) else {
        throw TerminalTabMoveError.itemNotFound(itemID)
      }
      if case .tab = itemID, case .group(let groupID, _) = location,
        !sourceGroupIDs.contains(groupID)
      {
        sourceGroupIDs.append(groupID)
      }
    }
    return MoveSource(groupIDs: sourceGroupIDs)
  }

  func validateDestination(
    _ destination: TerminalTabPlacement,
    for itemIDs: [TerminalTabRootItemID]
  ) throws {
    if case .group(let groupID, _) = destination {
      guard groupsByID[groupID] != nil else {
        throw TerminalTabMoveError.invalidDestination(destination)
      }
      guard itemIDs.allSatisfy({ if case .tab = $0 { true } else { false } }) else {
        throw TerminalTabMoveError.invalidDestination(destination)
      }
    }
  }

  mutating func insertMovedItems(
    _ itemIDs: [TerminalTabRootItemID],
    at destination: TerminalTabPlacement
  ) throws {
    switch destination {
    case .root(let placement):
      guard insertRootIDs(itemIDs, at: placement) else {
        throw TerminalTabMoveError.invalidDestination(destination)
      }
    case .group(let groupID, let index):
      guard var childIDs = childIDsByGroupID[groupID], (0...childIDs.count).contains(index)
      else {
        throw TerminalTabMoveError.invalidDestination(destination)
      }
      let tabIDs = itemIDs.compactMap { itemID -> TerminalTabID? in
        guard case .tab(let tabID) = itemID else { return nil }
        return tabID
      }
      childIDs.insert(contentsOf: tabIDs, at: index)
      childIDsByGroupID[groupID] = childIDs
    }
  }

  func location(of id: TerminalTabRootItemID) -> TerminalTabPlacement? {
    if let index = pinnedRootIDs.firstIndex(of: id) {
      return .root(TerminalRootPlacement(isPinned: true, index: index))
    }
    if let index = regularRootIDs.firstIndex(of: id) {
      return .root(TerminalRootPlacement(isPinned: false, index: index))
    }
    guard case .tab(let tabID) = id else { return nil }
    for (groupID, childIDs) in childIDsByGroupID {
      if let index = childIDs.firstIndex(of: tabID) {
        return .group(groupID, index: index)
      }
    }
    return nil
  }

  mutating func remove(_ id: TerminalTabRootItemID) {
    pinnedRootIDs.removeAll { $0 == id }
    regularRootIDs.removeAll { $0 == id }
    guard case .tab(let tabID) = id else { return }
    for groupID in childIDsByGroupID.keys {
      childIDsByGroupID[groupID]?.removeAll { $0 == tabID }
    }
  }

  mutating func insertTabID(_ id: TerminalTabID, at placement: TerminalTabPlacement) -> Bool {
    switch placement {
    case .root(let placement):
      return insertRootIDs([.tab(id)], at: placement)
    case .group(let groupID, let index):
      guard var childIDs = childIDsByGroupID[groupID], (0...childIDs.count).contains(index)
      else {
        return false
      }
      childIDs.insert(id, at: index)
      childIDsByGroupID[groupID] = childIDs
      return true
    }
  }

  mutating func insertRootID(
    _ id: TerminalTabRootItemID,
    at placement: TerminalRootPlacement
  ) -> Bool {
    insertRootIDs([id], at: placement)
  }

  mutating func insertRootIDs(
    _ ids: [TerminalTabRootItemID],
    at placement: TerminalRootPlacement
  ) -> Bool {
    if placement.isPinned {
      guard (0...pinnedRootIDs.count).contains(placement.index) else { return false }
      pinnedRootIDs.insert(contentsOf: ids, at: placement.index)
    } else {
      guard (0...regularRootIDs.count).contains(placement.index) else { return false }
      regularRootIDs.insert(contentsOf: ids, at: placement.index)
    }
    return true
  }

  mutating func appendRootID(_ id: TerminalTabRootItemID, isPinned: Bool) {
    if isPinned {
      pinnedRootIDs.append(id)
    } else {
      regularRootIDs.append(id)
    }
  }

  func rootIDs(isPinned: Bool) -> [TerminalTabRootItemID] {
    isPinned ? pinnedRootIDs : regularRootIDs
  }

  mutating func deleteAutomaticGroupIfEmpty(_ id: TerminalTabGroupID) -> Bool {
    guard groupsByID[id]?.lifetime == .automatic else { return false }
    guard childIDsByGroupID[id]?.isEmpty == true else { return false }
    deleteGroup(id)
    return true
  }

  mutating func deleteGroup(_ id: TerminalTabGroupID) {
    remove(.group(id))
    groupsByID[id] = nil
    childIDsByGroupID[id] = nil
  }
}
