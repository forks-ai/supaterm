import Foundation
import SupatermCLIShared
import Testing

extension SupatermE2ESuite {
  @Suite struct OnboardingTests {
    @Test(.timeLimit(.minutes(5)))
    func onboardingCommandWorksAndLaunchStateSuppressesSecondRun() async throws {
      let app = try await SupatermE2EApp.launch(shadowsBundledCLIAtShellStartup: true)
      defer { app.terminate() }

      let firstPane = try await initialPane(in: app)
      try await app.waitForCapture(firstPane, contains: "Welcome to Supaterm!")
      #expect(
        FileManager.default.fileExists(
          atPath: app.cliHome.appendingPathComponent("shell-startup").path
        )
      )
      #expect(!FileManager.default.fileExists(atPath: app.cliHome.appendingPathComponent("fake-sp").path))
      try app.type("/usr/bin/printf 'FIRST_LAUNCH_READY\\n'\n", into: firstPane)
      try await app.waitForCapture(firstPane, contains: "FIRST_LAUNCH_READY")

      let launchState = app.stateHome.appendingPathComponent("launch-state.json")
      try await app.waitUntil("the first launch state is saved") {
        FileManager.default.fileExists(atPath: launchState.path)
      }

      try await app.quit()
      let session = app.stateHome.appendingPathComponent("session.json")
      if FileManager.default.fileExists(atPath: session.path) {
        try FileManager.default.removeItem(at: session)
      }

      try await app.relaunch()
      let secondPane = try await initialPane(in: app)
      try app.type("/usr/bin/printf 'SECOND_LAUNCH_READY\\n'\n", into: secondPane)
      try await app.waitForCapture(secondPane, contains: "SECOND_LAUNCH_READY")
      let secondLaunchOutput = try app.capture(secondPane)
      #expect(!secondLaunchOutput.contains("Welcome to Supaterm!"))
    }
  }
}

private func initialPane(in app: SupatermE2EApp) async throws -> SupatermPaneTargetRequest {
  try await app.waitForDebugSnapshot("the initial pane is available") { snapshot in
    snapshot.windows.first?.spaces.first?.flattenedTabs.first?.panes.first != nil
  }
  let paneID = try #require(
    app.debugSnapshot().windows.first?.spaces.first?.flattenedTabs.first?.panes.first?.id
  )
  return SupatermPaneTargetRequest(paneID: paneID)
}
