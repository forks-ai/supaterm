import AppKit
import Foundation
import SupatermCLIShared
import Testing

extension SupatermE2ESuite {
  @Suite struct WindowLifecycleTests {
    @Test(.timeLimit(.minutes(5)))
    func appStaysBehindFrontmostApplication() async throws {
      let app = try await SupatermE2EApp.launch()
      defer { app.terminate() }

      let runningApp = try #require(
        NSRunningApplication(processIdentifier: app.processIdentifier)
      )
      #expect(!runningApp.isActive)
      try expectWindowIsBehindFrontmostApplication(processID: app.processIdentifier)

      let paneID = try #require(
        try app.debugSnapshot()
          .windows
          .first?
          .spaces
          .first?
          .flattenedTabs
          .first?
          .panes
          .first?
          .id
      )
      _ = try app.send(
        .focusPane(SupatermPaneTargetRequest(paneID: paneID)),
        as: SupatermFocusPaneResult.self
      )
      #expect(!runningApp.isActive)
      try expectWindowIsBehindFrontmostApplication(processID: app.processIdentifier)
    }

    @Test(.timeLimit(.minutes(5)))
    func closingLastPaneClosesWindow() async throws {
      let app = try await SupatermE2EApp.launch()
      defer { app.terminate() }

      var paneIDs = try app.debugSnapshot()
        .windows
        .flatMap(\.spaces)
        .flatMap(\.flattenedTabs)
        .flatMap(\.panes)
        .map(\.id)
      #expect(!paneIDs.isEmpty)

      while let paneID = paneIDs.popLast() {
        _ = try app.send(
          .closePane(SupatermPaneTargetRequest(paneID: paneID)),
          as: SupatermClosePaneResult.self
        )
      }

      try await app.waitUntil("the last window closes") {
        try app.debugSnapshot().summary.windowCount == 0
      }
      #expect(try app.debugSnapshot().problems.contains("No active windows."))
    }

    @Test(.timeLimit(.minutes(5)))
    func closeOnlyRemainingSpaceFails() async throws {
      let app = try await SupatermE2EApp.launch()
      defer { app.terminate() }

      let snapshot = try app.debugSnapshot()
      let window = try #require(snapshot.windows.first)
      #expect(window.spaces.count == 1)
      let space = try #require(window.spaces.first)

      let message = try app.sendExpectingError(
        .closeSpace(SupatermSpaceTargetRequest(spaceID: space.id))
      )
      #expect(!message.isEmpty)

      let after = try app.debugSnapshot()
      #expect(after.windows.first?.spaces.map(\.id) == [space.id])
    }
  }
}

private func expectWindowIsBehindFrontmostApplication(processID: pid_t) throws {
  let frontmostProcessID = try #require(
    NSWorkspace.shared.frontmostApplication?.processIdentifier
  )
  #expect(frontmostProcessID != processID)
  let owners = try #require(
    CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
      as? [[CFString: Any]]
  )
  let processIndex = try #require(
    owners.firstIndex { ($0[kCGWindowOwnerPID] as? NSNumber)?.int32Value == processID }
  )
  let ownerIndex = try #require(
    owners.firstIndex { ($0[kCGWindowOwnerPID] as? NSNumber)?.int32Value == frontmostProcessID }
  )
  #expect(processIndex > ownerIndex)
}
