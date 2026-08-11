import AppKit
import Foundation
import GhosttyKit
import Testing

@testable import SupatermCLIShared
@testable import supaterm

@MainActor
struct GhosttySurfaceViewEnvironmentTests {
  @Test
  func surfaceCreationUsesAccountShellAndKeepsArgumentsOutOfItsEnvironment() throws {
    initializeGhosttyForTests()
    let secret = "startup-secret-\(UUID().uuidString.lowercased())"
    var command: String?
    var initialInput: String?
    var environment: [String: String] = [:]
    var payloadArguments: [String]?

    _ = GhosttySurfaceView(
      runtime: try makeGhosttyRuntime("command = /usr/bin/false"),
      tabID: UUID(),
      workingDirectory: nil,
      shellPath: "/bin/bash",
      cliPath: "/usr/bin/true",
      startupCommand: .arguments(["tool", secret]),
      context: GHOSTTY_SURFACE_CONTEXT_TAB,
      surfaceFactory: { _, config in
        command = config.pointee.command.map(String.init(cString:))
        initialInput = config.pointee.initial_input.map(String.init(cString:))
        if let variables = config.pointee.env_vars {
          for index in 0..<config.pointee.env_var_count {
            let variable = variables[index]
            if let key = variable.key, let value = variable.value {
              environment[String(cString: key)] = String(cString: value)
            }
          }
        }
        if let initialInput {
          let launcherURL = URL(fileURLWithPath: initialInput.trimmingCharacters(in: .newlines))
          let payloadURL = launcherURL.deletingLastPathComponent()
            .appendingPathComponent("arguments.json")
          payloadArguments = try? JSONDecoder().decode(
            [String].self,
            from: Data(contentsOf: payloadURL)
          )
        }
        return nil
      }
    )

    #expect(command == "/bin/bash")
    #expect(initialInput?.hasPrefix("/private/tmp/supaterm-startup-") == true)
    #expect(payloadArguments == ["tool", secret])
    #expect(!environment.values.contains { $0.contains(secret) })
    if let initialInput {
      let directoryPath = URL(fileURLWithPath: initialInput.trimmingCharacters(in: .newlines))
        .deletingLastPathComponent().path
      #expect(!FileManager.default.fileExists(atPath: directoryPath))
    }
  }

  @Test
  func integratedShellsDeferStartupInputUntilTheirPromptIsReady() throws {
    initializeGhosttyForTests()
    let runtime = try makeGhosttyRuntime("")
    #expect(runtime.defersInitialInputUntilShellReady(shellPath: "/bin/zsh"))
    #expect(runtime.defersInitialInputUntilShellReady(shellPath: "/opt/homebrew/bin/fish"))
    #expect(!runtime.defersInitialInputUntilShellReady(shellPath: "/bin/bash"))

    let launch = GhosttySurfaceLaunch(
      shellPath: "/bin/zsh",
      cliPath: "/usr/bin/true",
      startup: .arguments(["tool"]),
      defersInputUntilShellReady: true
    )
    var config = ghostty_surface_config_new()
    launch.apply(to: &config)
    #expect(config.initial_input == nil)
    #expect(
      launch.takeDeferredInput()?
        .hasPrefix("/private/tmp/supaterm-startup-") == true
    )
    #expect(launch.takeDeferredInput() == nil)
    launch.cancel()
  }

  @Test
  func disabledShellIntegrationKeepsImmediateStartupInput() throws {
    initializeGhosttyForTests()
    let runtime = try makeGhosttyRuntime("shell-integration = none")
    #expect(!runtime.defersInitialInputUntilShellReady(shellPath: "/bin/zsh"))
    #expect(!runtime.defersInitialInputUntilShellReady(shellPath: "/opt/homebrew/bin/fish"))
  }

  @Test
  func missingCLIShowsStartupPreparationFailure() throws {
    initializeGhosttyForTests()
    var createdSurface = false

    let surfaceView = GhosttySurfaceView(
      runtime: try makeGhosttyRuntime(""),
      tabID: UUID(),
      workingDirectory: nil,
      shellPath: "/bin/zsh",
      cliPath: nil,
      startupCommand: .arguments(["pwd"]),
      context: GHOSTTY_SURFACE_CONTEXT_TAB,
      surfaceFactory: { _, _ in
        createdSurface = true
        return nil
      }
    )

    #expect(!createdSurface)
    #expect(surfaceView.bridge.state.failure == .startupPreparationFailed)
  }

  @Test
  func supatermEnvironmentVariablesIncludePaneSocketCliAndPrependedPath() {
    let surfaceID = UUID(uuidString: "A72F7A7D-B5E8-497E-A5D5-D26A77A0A4C7")!
    let tabID = UUID(uuidString: "9F4EB4BE-9216-4DCA-A866-C8276D9EF2AA")!
    let path = [
      "/Applications/Supaterm.app/Contents/MacOS",
      "/usr/local/bin",
      "/usr/bin",
      "/bin",
    ].joined(separator: ":")
    let environmentVariables = GhosttySurfaceView.supatermEnvironmentVariables(
      surfaceID: surfaceID,
      tabID: tabID,
      socketPath: "/tmp/supaterm.sock",
      cliPath: "/Applications/Supaterm.app/Contents/MacOS/sp",
      processEnvironment: ["PATH": "/usr/local/bin:/usr/bin:/bin"]
    )

    #expect(
      environmentVariables == [
        SupatermCLIEnvironmentVariable(key: SupatermCLIEnvironment.surfaceIDKey, value: surfaceID.uuidString),
        SupatermCLIEnvironmentVariable(key: SupatermCLIEnvironment.tabIDKey, value: tabID.uuidString),
        SupatermCLIEnvironmentVariable(key: SupatermCLIEnvironment.socketPathKey, value: "/tmp/supaterm.sock"),
        SupatermCLIEnvironmentVariable(
          key: SupatermCLIEnvironment.cliPathKey,
          value: "/Applications/Supaterm.app/Contents/MacOS/sp"
        ),
        SupatermCLIEnvironmentVariable(key: ZmxEnvironment.directoryKey, value: "/tmp/zmx-\(getuid())"),
        SupatermCLIEnvironmentVariable(key: ZmxEnvironment.sessionKey, value: ""),
        SupatermCLIEnvironmentVariable(key: ZmxEnvironment.sessionPrefixKey, value: ""),
        SupatermCLIEnvironmentVariable(key: "PATH", value: path),
      ]
    )
  }

  @Test
  func prependedPathMovesCliDirectoryToFrontWithoutDuplication() {
    #expect(
      GhosttySurfaceView.prependedPath(
        "/Applications/Supaterm.app/Contents/MacOS",
        currentPath: "/usr/local/bin:/Applications/Supaterm.app/Contents/MacOS:/usr/bin"
      ) == "/Applications/Supaterm.app/Contents/MacOS:/usr/local/bin:/usr/bin"
    )
  }

  @Test
  func cliDirectoryReturnsBundledExecutableDirectory() {
    #expect(
      GhosttySurfaceView.cliDirectory("/Applications/Supaterm.app/Contents/MacOS/sp")
        == "/Applications/Supaterm.app/Contents/MacOS"
    )
  }

  @Test
  func supatermEnvironmentVariablesUseShortZmxDirectory() {
    let environmentVariables = GhosttySurfaceView.supatermEnvironmentVariables(
      surfaceID: UUID(),
      tabID: UUID(),
      socketPath: nil,
      cliPath: nil,
      processEnvironment: [
        "ZMX_DIR": "/var/folders/" + String(repeating: "a", count: 80),
        "XDG_RUNTIME_DIR": "/var/folders/" + String(repeating: "b", count: 80),
        "TMPDIR": "/var/folders/" + String(repeating: "c", count: 80),
      ]
    )

    #expect(
      environmentVariables.contains(
        SupatermCLIEnvironmentVariable(key: ZmxEnvironment.directoryKey, value: "/tmp/zmx-\(getuid())")
      )
    )
  }

  @Test
  func supatermEnvironmentVariablesClearInheritedZmxSessionContext() {
    let environmentVariables = GhosttySurfaceView.supatermEnvironmentVariables(
      surfaceID: UUID(),
      tabID: UUID(),
      socketPath: nil,
      cliPath: nil,
      processEnvironment: [
        ZmxEnvironment.sessionKey: "parent-session",
        ZmxEnvironment.sessionPrefixKey: "parent-prefix-",
      ]
    )

    #expect(environmentVariables.contains(SupatermCLIEnvironmentVariable(key: ZmxEnvironment.sessionKey, value: "")))
    #expect(
      environmentVariables.contains(SupatermCLIEnvironmentVariable(key: ZmxEnvironment.sessionPrefixKey, value: ""))
    )
  }

  @Test
  func supatermEnvironmentVariablesOmitZmxDirectoryWhenZmxSessionsAreDisabled() {
    let environmentVariables = GhosttySurfaceView.supatermEnvironmentVariables(
      surfaceID: UUID(),
      tabID: UUID(),
      socketPath: nil,
      cliPath: nil,
      zmxSessionsEnabled: false
    )

    #expect(!environmentVariables.contains { $0.key == ZmxEnvironment.directoryKey })
    #expect(!environmentVariables.contains { $0.key == ZmxEnvironment.sessionKey })
    #expect(!environmentVariables.contains { $0.key == ZmxEnvironment.sessionPrefixKey })
  }

  @Test
  func supatermEnvironmentVariablesIncludeStateHomeWhenPresent() {
    let environmentVariables = GhosttySurfaceView.supatermEnvironmentVariables(
      surfaceID: UUID(),
      tabID: UUID(),
      socketPath: nil,
      cliPath: nil,
      processEnvironment: [SupatermCLIEnvironment.stateHomeKey: "/tmp/supaterm-dev"]
    )

    #expect(
      environmentVariables.contains(
        SupatermCLIEnvironmentVariable(key: SupatermCLIEnvironment.stateHomeKey, value: "/tmp/supaterm-dev")
      )
    )
  }

  @Test
  func titleOverrideTreatsEmptyStringAsRestoreDefault() {
    #expect(GhosttySurfaceView.titleOverride(from: "") == nil)
  }

  @Test
  func titleOverridePreservesWhitespaceAndColons() {
    #expect(GhosttySurfaceView.titleOverride(from: "  ") == "  ")
    #expect(GhosttySurfaceView.titleOverride(from: "foo:bar") == "foo:bar")
  }

  @Test
  func workingDirectoryPathNormalizesRepeatedAndTrailingSeparators() {
    #expect(
      GhosttySurfaceView.normalizedWorkingDirectoryPath("/tmp//project///src/")
        == "/tmp/project/src"
    )
    #expect(GhosttySurfaceView.normalizedWorkingDirectoryPath("/") == "/")
  }

  @Test
  func scrollOnFocusedSurfaceCountsAsDirectInteraction() throws {
    initializeGhosttyForTests()

    let runtime = GhosttyRuntime()
    let view = GhosttySurfaceView(
      runtime: runtime,
      tabID: UUID(),
      workingDirectory: nil,
      context: GHOSTTY_SURFACE_CONTEXT_TAB
    )
    var interactionCount = 0
    view.onDirectInteraction = {
      interactionCount += 1
    }
    view.focusDidChange(true)
    let cgEvent = try #require(
      CGEvent(
        scrollWheelEvent2Source: nil,
        units: .pixel,
        wheelCount: 1,
        wheel1: 1,
        wheel2: 0,
        wheel3: 0
      )
    )
    let scrollEvent = try #require(NSEvent(cgEvent: cgEvent))

    view.scrollWheel(with: scrollEvent)

    #expect(interactionCount == 1)
  }
}
