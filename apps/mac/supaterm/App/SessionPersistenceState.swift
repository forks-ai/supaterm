import AppKit

enum SessionPersistenceState: Equatable {
  case active
  case restoring
  case quitting(TerminalSessionCatalog)
  case quittingAfterSessionTermination(TerminalSessionCatalog)

  var allowsLiveSave: Bool {
    self == .active
  }

  var shortCircuitsTerminateReply: Bool {
    if case .quittingAfterSessionTermination = self {
      return true
    }
    return false
  }

  func catalogToPersist(liveCatalog: TerminalSessionCatalog) -> TerminalSessionCatalog {
    switch self {
    case .active, .restoring:
      return liveCatalog
    case .quitting(let catalog), .quittingAfterSessionTermination(let catalog):
      return catalog
    }
  }

  static func afterTerminationDecision(
    reply: NSApplication.TerminateReply,
    terminatesSessions: Bool,
    liveCatalog: TerminalSessionCatalog
  ) -> Self {
    guard reply == .terminateNow else { return .active }
    return terminatesSessions
      ? .quittingAfterSessionTermination(liveCatalog)
      : .quitting(liveCatalog)
  }
}
