import Foundation
import SupatermCLIShared
import SupatermTerminalCore

extension TerminalCommandExecutor {
  func createSpace(_ request: TerminalCreateSpaceRequest) throws -> SupatermCreateSpaceResult {
    guard
      registry.activeEntries().contains(where: {
        $0.terminal.tabID(containing: request.windowAnchorPaneID) != nil
      })
    else {
      throw TerminalControlError.contextPaneNotFound
    }
    return try registry.createSpaceResult(named: request.name, focus: request.focus)
  }

  func selectSpace(_ target: TerminalSpaceTarget) throws -> SupatermSelectSpaceResult {
    try registry.selectSpaceResult(TerminalSpaceID(rawValue: target.spaceID))
  }

  func closeSpace(_ target: TerminalSpaceTarget) throws -> SupatermCloseSpaceResult {
    try registry.deleteSpaceResult(TerminalSpaceID(rawValue: target.spaceID))
  }

  func renameSpace(_ request: TerminalRenameSpaceRequest) throws -> SupatermSpaceTarget {
    try registry.renameSpaceResult(
      TerminalSpaceID(rawValue: request.target.spaceID),
      to: request.name
    )
  }

  func nextSpace(_ request: TerminalSpaceNavigationRequest) throws -> SupatermSelectSpaceResult {
    try registry.adjacentSpaceResult(
      from: TerminalSpaceID(rawValue: request.spaceID),
      step: 1
    )
  }

  func previousSpace(_ request: TerminalSpaceNavigationRequest) throws -> SupatermSelectSpaceResult {
    try registry.adjacentSpaceResult(
      from: TerminalSpaceID(rawValue: request.spaceID),
      step: -1
    )
  }

  func lastSpace(_ request: TerminalSpaceNavigationRequest) throws -> SupatermSelectSpaceResult {
    try registry.lastSpaceResult(from: TerminalSpaceID(rawValue: request.spaceID))
  }
}
