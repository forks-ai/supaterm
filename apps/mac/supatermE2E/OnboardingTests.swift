import Foundation
import SupatermCLIShared
import Testing

extension SupatermE2ESuite {
  @Suite struct OnboardingTests {
    @Test(.timeLimit(.minutes(5)))
    func onboardingCommandWorksAndLaunchStateSuppressesSecondRun() async throws {
      let app = try await SupatermE2EApp.launch()
      defer { app.terminate() }

      let runner = SPBinaryRunner(
        executable: app.spExecutable,
        environment: app.cliEnvironment()
      )
      let onboarding = try requireSuccessfulSPResult(
        try runner.run(["onboard", "--socket", app.socketPath, "--plain"], cwd: app.cliHome)
      )
      #expect(onboarding.stdout.contains("Welcome to Supaterm!"))

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
