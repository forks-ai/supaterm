import Foundation
import SupatermCLIShared
import Testing

@Suite struct TerminalSmokeTests {
  @Test(.timeLimit(.minutes(10)))
  func shellRoundTripAcrossTabAndSplit() async throws {
    let app = try await SupatermE2EApp.launch()
    defer { app.terminate() }

    let token = String(UUID().uuidString.prefix(8).lowercased())
    let outputMarker = "E2EOK\(token)"
    let typedMarker = "E2E''OK\(token)"

    let startup = try app.send(.debug(SupatermDebugRequest()), as: SupatermAppDebugSnapshot.self)
    let window = try #require(startup.windows.first)
    let space = try #require(window.spaces.first)

    let tab = try app.send(
      .newTab(
        SupatermNewTabRequest(
          cwd: app.stateHome.path,
          focus: true,
          targetWindowIndex: window.index,
          targetSpaceIndex: space.index
        )
      ),
      as: SupatermNewTabResult.self
    )
    let pane = SupatermPaneTargetRequest(contextPaneID: tab.paneID)

    try await app.waitForReadyPane(pane)
    try await app.waitUntil("the shell renders a prompt") {
      try !app.capture(pane).trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    _ = try app.send(
      .sendText(
        SupatermSendTextRequest(
          target: pane,
          text: "echo \(typedMarker) > round-trip.txt; cat round-trip.txt"
        )
      ),
      as: SupatermSendTextResult.self
    )
    try await app.waitForCapture(pane, contains: typedMarker)
    #expect(try !app.capture(pane).contains(outputMarker))

    _ = try app.send(
      .sendKey(SupatermSendKeyRequest(key: .enter, target: pane)),
      as: SupatermSendKeyResult.self
    )
    let resultFile = app.stateHome.appendingPathComponent("round-trip.txt")
    try await app.waitUntil("the shell writes round-trip.txt") {
      (try? String(contentsOf: resultFile, encoding: .utf8))?.contains(outputMarker) == true
    }
    try await app.waitForCapture(pane, contains: outputMarker)

    let split = try app.send(
      .newPane(
        SupatermNewPaneRequest(
          contextPaneID: tab.paneID,
          cwd: app.stateHome.path,
          direction: .right,
          focus: true,
          equalize: true
        )
      ),
      as: SupatermNewPaneResult.self
    )
    #expect(split.tabID == tab.tabID)
    #expect(split.paneID != tab.paneID)

    let splitPane = SupatermPaneTargetRequest(contextPaneID: split.paneID)
    try await app.waitForReadyPane(splitPane)
    _ = try app.send(
      .sendText(
        SupatermSendTextRequest(target: splitPane, text: "echo SPLIT''OK\(token) > split.txt\n")
      ),
      as: SupatermSendTextResult.self
    )
    let splitFile = app.stateHome.appendingPathComponent("split.txt")
    try await app.waitUntil("the split shell writes split.txt") {
      (try? String(contentsOf: splitFile, encoding: .utf8))?.contains("SPLITOK\(token)") == true
    }

    let snapshot = try app.send(.debug(SupatermDebugRequest()), as: SupatermAppDebugSnapshot.self)
    let panes =
      snapshot.windows
      .flatMap(\.spaces)
      .flatMap(\.tabs)
      .first { $0.id == tab.tabID }?
      .panes ?? []
    #expect(Set(panes.map(\.id)) == [tab.paneID, split.paneID])
  }
}
