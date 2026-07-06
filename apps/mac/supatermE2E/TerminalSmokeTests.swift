import Foundation
import SupatermCLIShared
import Testing

extension SupatermE2ESuite {
  @Suite struct TerminalSmokeTests {
    @Test(.timeLimit(.minutes(5)))
    func shellRoundTripAcrossTabAndSplit() async throws {
      try await withTestSpace { app, space in
        let outputMarker = "E2EOK\(space.token)"
        let typedMarker = "E2E''OK\(space.token)"
        let pane = space.pane

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
        let resultFile = space.directory.appendingPathComponent("round-trip.txt")
        try await app.waitUntil("the shell writes round-trip.txt") {
          (try? String(contentsOf: resultFile, encoding: .utf8))?.contains(outputMarker) == true
        }
        try await app.waitForCapture(pane, contains: outputMarker)

        let split = try app.send(
          .newPane(
            SupatermNewPaneRequest(
              startupCommand: hermeticShellStartupCommand,
              contextPaneID: space.tab.paneID,
              cwd: space.directory.path,
              direction: .right,
              focus: true,
              equalize: true
            )
          ),
          as: SupatermNewPaneResult.self
        )
        #expect(split.tabID == space.tab.tabID)
        #expect(split.paneID != space.tab.paneID)

        let splitPane = SupatermPaneTargetRequest(contextPaneID: split.paneID)
        try await app.waitForReadyPane(splitPane)
        _ = try app.send(
          .sendText(
            SupatermSendTextRequest(
              target: splitPane,
              text: "echo SPLIT''OK\(space.token) > split.txt\n"
            )
          ),
          as: SupatermSendTextResult.self
        )
        let splitFile = space.directory.appendingPathComponent("split.txt")
        try await app.waitUntil("the split shell writes split.txt") {
          (try? String(contentsOf: splitFile, encoding: .utf8))?.contains("SPLITOK\(space.token)") == true
        }

        let snapshot = try app.debugSnapshot()
        let panes =
          snapshot.windows
          .flatMap(\.spaces)
          .flatMap(\.tabs)
          .first { $0.id == space.tab.tabID }?
          .panes ?? []
        #expect(Set(panes.map(\.id)) == [space.tab.paneID, split.paneID])
      }
    }
  }
}
