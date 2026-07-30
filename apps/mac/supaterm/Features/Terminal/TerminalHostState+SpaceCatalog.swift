import AppKit
import Foundation
import GhosttyKit
import Observation
import Sharing
import SwiftUI

extension TerminalHostState {
  func isSpaceNameAvailable(
    _ proposedName: String,
    excluding excludedSpaceID: TerminalSpaceID? = nil
  ) -> Bool {
    guard let name = Self.trimmedNonEmpty(proposedName) else { return false }
    return !TerminalSpaceCatalog.sanitized(spaceCatalog).spaces.contains {
      $0.id != excludedSpaceID && $0.name.localizedCaseInsensitiveCompare(name) == .orderedSame
    }
  }

  func observeSpaceCatalog() {
    spaceCatalogObservationTask?.cancel()
    spaceCatalogObservationTask = Task { @MainActor [weak self] in
      let observations = Observations { [weak self] in
        self?.spaceCatalog ?? .default
      }
      for await spaceCatalog in observations {
        guard let self else { return }
        self.applyObservedSpaceCatalog(spaceCatalog)
      }
    }
  }

  func applyObservedSpaceCatalog(_ spaceCatalog: TerminalSpaceCatalog) {
    let resolvedSpaceCatalog = TerminalSpaceCatalog.sanitized(spaceCatalog)
    guard resolvedSpaceCatalog != lastAppliedSpaceCatalog else { return }

    lastAppliedSpaceCatalog = resolvedSpaceCatalog
    spaceManager.applyCatalog(resolvedSpaceCatalog)
  }

  func replaceSpaceCatalog(_ spaceCatalog: TerminalSpaceCatalog) {
    $spaceCatalog.withLock { $0 = spaceCatalog }
  }
}
