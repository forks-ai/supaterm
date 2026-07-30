import AppKit
import Foundation
import GhosttyKit
import Observation
import Sharing
import SwiftUI

extension TerminalHostState {
  func applySelectedTab(
    _ tabID: TerminalTabID,
    in spaceID: TerminalSpaceID
  ) {
    let currentSelectedTabID = spaceManager.selectedTabID(in: spaceID)
    if currentSelectedTabID != tabID, let currentSelectedTabID {
      previousSelectedTabIDBySpace[spaceID] = currentSelectedTabID
    }
    spaceManager.tabManager(for: spaceID)?.selectTab(tabID)
    if let groupID = spaceManager.tabManager(for: spaceID)?.groupID(containing: tabID) {
      collapsedTabGroupIDsBySpace[spaceID]?.remove(groupID)
    }
  }

  func selectTab(_ tabID: TerminalTabID) {
    guard let space = spaceManager.space(for: tabID) else { return }
    applySelectedTab(tabID, in: space.id)
    focusSurfaceIfNeeded(in: tabID)
    syncFocus(windowActivity)
    sessionDidChange()
  }

  func selectTab(slot: Int) {
    let index = slot - 1
    guard visibleTabs.indices.contains(index) else { return }
    selectTab(visibleTabs[index].id)
  }

  func nextTab() {
    guard
      let selectedTabID,
      let selectedIndex = tabs.firstIndex(where: { $0.id == selectedTabID }),
      !tabs.isEmpty
    else {
      return
    }
    let nextIndex = (selectedIndex + 1) % tabs.count
    selectTab(tabs[nextIndex].id)
  }

  func previousTab() {
    guard
      let selectedTabID,
      let selectedIndex = tabs.firstIndex(where: { $0.id == selectedTabID }),
      !tabs.isEmpty
    else {
      return
    }
    let previousIndex = (selectedIndex - 1 + tabs.count) % tabs.count
    selectTab(tabs[previousIndex].id)
  }

  func selectLastTab() {
    guard let selectedSpaceID else { return }
    guard let lastTabID = previousSelectedTabIDBySpace[selectedSpaceID] else { return }
    selectTab(lastTabID)
  }

  func updateSelectionAfterClosingTab(
    in spaceID: TerminalSpaceID,
    wasSelectedSpace: Bool,
    didCloseSelectedTab: Bool
  ) {
    guard wasSelectedSpace else { return }

    if let selectedTabID = spaceManager.selectedTabID(in: spaceID) {
      if isSelectableTab(selectedTabID) {
        if didCloseSelectedTab {
          applySelectedTab(selectedTabID, in: spaceID)
        }
        focusSurfaceIfNeeded(in: selectedTabID)
        return
      }
    }

    if let tabID = replacementLiveTabID(in: spaceID) {
      applySelectedTab(tabID, in: spaceID)
      focusSurfaceIfNeeded(in: tabID)
      return
    }

    spaceManager.tabManager(for: spaceID)?.clearSelection()

    lastEmittedFocusSurfaceID = nil
  }

  func replacementLiveTabID(in spaceID: TerminalSpaceID) -> TerminalTabID? {
    let tabs = spaceManager.tabs(in: spaceID)
    if let previousTabID = previousSelectedTabIDBySpace[spaceID],
      tabs.contains(where: { $0.id == previousTabID }),
      isSelectableTab(previousTabID)
    {
      return previousTabID
    }
    return tabs.reversed().first { isSelectableTab($0.id) }?.id
  }

  func isSelectableTab(_ tabID: TerminalTabID) -> Bool {
    !managesTerminalSurfaces || trees[tabID] != nil
  }

  func focusSurfaceIfNeeded(in tabID: TerminalTabID) {
    guard managesTerminalSurfaces else {
      lastEmittedFocusSurfaceID = nil
      return
    }
    focusSurface(in: tabID)
  }

}
