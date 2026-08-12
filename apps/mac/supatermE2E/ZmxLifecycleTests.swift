import Darwin
import Foundation
import SupatermCLIShared
import Testing

extension SupatermE2ESuite {
  @Suite struct ZmxLifecycleTests {
    @Test(.timeLimit(.minutes(5)))
    func directProcessSurvivesRelaunchAndItsPaneClosesOnExit() async throws {
      let app = try await SupatermE2EApp.launch(zmxSessionsEnabled: true)
      defer { app.terminate() }

      let directory = app.stateHome.appendingPathComponent("zmx-lifecycle", isDirectory: true)
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      let processIDFile = directory.appendingPathComponent("pid")
      let stopFile = directory.appendingPathComponent("stop")
      let command = [
        "/bin/sh",
        "-c",
        "printf '%s\\n' \"$$\" > \"$1\"; while [ ! -e \"$2\" ]; do /bin/sleep 0.1; done",
        "zmx-lifecycle",
        processIDFile.path,
        stopFile.path,
      ]
      let space = try app.send(
        .createSpace(SupatermCreateSpaceRequest(color: nil, name: "zmx-lifecycle")),
        as: SupatermCreateSpaceResult.self
      )
      let tab = try app.send(
        .newTab(
          SupatermNewTabRequest(
            startupCommand: .exec(command, searchPath: "/usr/bin:/bin"),
            cwd: directory.path,
            focus: true,
            target: .space(space.target.spaceID)
          )
        ),
        as: SupatermNewTabResult.self
      )

      try await app.waitUntil("the direct process writes its process ID") {
        try readProcessID(processIDFile) != nil
      }
      let processID = try #require(try readProcessID(processIDFile))
      #expect(kill(processID, 0) == 0)
      try await app.waitForPersistedStateQuiescence(containing: [tab.paneID.uuidString])

      try await app.quit()
      #expect(kill(processID, 0) == 0)
      try await app.relaunch()
      try await app.waitForDebugSnapshot("the direct process pane reattaches") { snapshot in
        snapshot.windows
          .flatMap(\.spaces)
          .flatMap(\.flattenedTabs)
          .flatMap(\.panes)
          .contains { $0.id == tab.paneID }
      }
      #expect(try readProcessID(processIDFile) == processID)
      #expect(kill(processID, 0) == 0)

      try Data().write(to: stopFile)
      try await app.waitUntil("the finished direct process pane closes") {
        try app.debugPane(tab.paneID) == nil
      }
    }
  }
}

private func readProcessID(_ url: URL) throws -> pid_t? {
  guard let value = try? String(contentsOf: url, encoding: .utf8),
    let processID = pid_t(value.trimmingCharacters(in: .whitespacesAndNewlines))
  else {
    return nil
  }
  return processID
}
