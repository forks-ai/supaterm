import Foundation
import SupatermCLIShared
import Testing

@testable import SPCLI

struct SPConfigSocketContractTests {
  @Test
  func getSendsSettingsGetAndRendersEveryOutputMode() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let log = SPSocketRequestLog()
    let result = SupatermSettingsGetResult(
      path: "/tmp/settings.toml",
      entry: appearanceModeEntry,
      warnings: ["Unknown config key `obsolete`."]
    )

    try await withSocketRuntime(
      replying: { request, _ in
        log.record(request)
        return try .ok(id: request.id, encodableResult: result)
      },
      run: { endpoint in
        let socket = ["--socket", endpoint.path]
        let human = try cli.run(["config", "get", "appearance.mode"] + socket)
        let plain = try cli.run(["config", "get", "appearance.mode", "--plain"] + socket)
        let json = try cli.run(["config", "get", "appearance.mode", "--json"] + socket)
        let quiet = try cli.run(["config", "get", "appearance.mode", "--quiet"] + socket)

        #expect(
          human
            == SPCLIResult(
              exitCode: 0,
              stdout: """
                appearance.mode = system
                warning: Unknown config key `obsolete`.

                """,
              stderr: ""
            )
        )
        #expect(plain.stdout == "appearance.mode\tsystem\n")
        #expect(
          json.stdout == """
            {"entry":{"allowedValues":["system","light","dark"],"defaultValue":"dark",\
            "isDefault":false,"key":"appearance.mode","value":"system","valueKind":"string"},\
            "path":"\\/tmp\\/settings.toml","warnings":["Unknown config key `obsolete`."]}

            """
        )
        #expect(quiet.stdout.isEmpty)
      }
    )

    #expect(log.requests.map(\.method) == Array(repeating: SupatermSocketMethod.appSettingsGet, count: 4))
    #expect(
      try log.requests.map { try jsonString($0.params) } == Array(repeating: #"{"key":"appearance.mode"}"#, count: 4))
  }

  @Test
  func listSendsSettingsListAndRendersEveryOutputMode() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let log = SPSocketRequestLog()
    let result = SupatermSettingsListResult(
      path: "/tmp/settings.toml",
      entries: [appearanceModeEntry],
      warnings: ["Unknown config key `obsolete`."]
    )

    try await withSocketRuntime(
      replying: { request, _ in
        log.record(request)
        return try .ok(id: request.id, encodableResult: result)
      },
      run: { endpoint in
        let socket = ["--socket", endpoint.path]
        let human = try cli.run(["config", "list"] + socket)
        let plain = try cli.run(["config", "list", "--plain"] + socket)
        let changed = try cli.run(["config", "list", "--changed", "--plain"] + socket)

        #expect(
          human.stdout == """
            appearance.mode = system
            warning: Unknown config key `obsolete`.

            """
        )
        #expect(
          plain.stdout == """
            appearance.mode\tsystem
            warning\tUnknown config key `obsolete`.

            """
        )
        #expect(changed.exitCode == 0)
      }
    )

    #expect(log.requests.map(\.method) == Array(repeating: SupatermSocketMethod.appSettingsList, count: 3))
    #expect(
      try log.requests.map { try jsonString($0.params) } == [
        #"{"changedOnly":false}"#,
        #"{"changedOnly":false}"#,
        #"{"changedOnly":true}"#,
      ]
    )
  }

  @Test
  func emptyListRendersPlaceholderInHumanMode() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let result = SupatermSettingsListResult(path: "/tmp/settings.toml", entries: [])

    try await withSocketRuntime(
      replying: { request, _ in try .ok(id: request.id, encodableResult: result) },
      run: { endpoint in
        let human = try cli.run(["config", "list", "--changed", "--socket", endpoint.path])
        let plain = try cli.run(["config", "list", "--changed", "--plain", "--socket", endpoint.path])

        #expect(human.stdout == "No changed settings.\n")
        #expect(plain.stdout == "\n")
      }
    )
  }

  @Test
  func setAndResetSendMutationRequestsAndRenderEveryOutputMode() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let log = SPSocketRequestLog()
    let result = SupatermSettingsMutationResult(
      path: "/tmp/settings.toml",
      key: "appearance.mode",
      oldValue: "dark",
      value: "system",
      defaultValue: "dark",
      isDefault: false,
      warnings: ["macOS notification permission may still be required."]
    )

    try await withSocketRuntime(
      replying: { request, _ in
        log.record(request)
        return try .ok(id: request.id, encodableResult: result)
      },
      run: { endpoint in
        let socket = ["--socket", endpoint.path]
        let set = try cli.run(["config", "set", "appearance.mode", "system"] + socket)
        let setPlain = try cli.run(["config", "set", "appearance.mode", "system", "--plain"] + socket)
        let setJSON = try cli.run(["config", "set", "appearance.mode", "system", "--json"] + socket)
        let reset = try cli.run(["config", "reset", "appearance.mode"] + socket)
        let resetPlain = try cli.run(["config", "reset", "appearance.mode", "--plain"] + socket)

        #expect(
          set.stdout == """
            Updated appearance.mode: dark -> system
            warning: macOS notification permission may still be required.

            """
        )
        #expect(setPlain.stdout == "appearance.mode\tdark\tsystem\n")
        #expect(
          setJSON.stdout == """
            {"defaultValue":"dark","isDefault":false,"key":"appearance.mode","oldValue":"dark",\
            "path":"\\/tmp\\/settings.toml","value":"system",\
            "warnings":["macOS notification permission may still be required."]}

            """
        )
        #expect(
          reset.stdout == """
            Reset appearance.mode: dark -> system
            warning: macOS notification permission may still be required.

            """
        )
        #expect(resetPlain.stdout == "appearance.mode\tdark\tsystem\n")
      }
    )

    #expect(
      log.requests.map(\.method) == [
        SupatermSocketMethod.appSettingsSet,
        SupatermSocketMethod.appSettingsSet,
        SupatermSocketMethod.appSettingsSet,
        SupatermSocketMethod.appSettingsReset,
        SupatermSocketMethod.appSettingsReset,
      ]
    )
    #expect(
      try log.requests.map { try jsonString($0.params) } == [
        #"{"key":"appearance.mode","value":"system"}"#,
        #"{"key":"appearance.mode","value":"system"}"#,
        #"{"key":"appearance.mode","value":"system"}"#,
        #"{"key":"appearance.mode"}"#,
        #"{"key":"appearance.mode"}"#,
      ]
    )
  }

  @Test
  func socketErrorResponseFailsWithTheServerMessage() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    try await withSocketRuntime(
      replying: { request, _ in
        .error(id: request.id, code: "invalid_key", message: "Unknown config key `nope`.")
      },
      run: { endpoint in
        let socket = ["--socket", endpoint.path]
        for arguments in [
          ["config", "get", "nope"],
          ["config", "list"],
          ["config", "set", "nope", "1"],
          ["config", "reset", "nope"],
        ] {
          let result = try cli.run(arguments + socket)
          #expect(result.exitCode == 64)
          #expect(result.stdout.isEmpty)
          #expect(result.stderr.hasPrefix("Error: Unknown config key `nope`.\n"))
        }
      }
    )
  }

  @Test
  func socketPathIsPreferredOverTheOfflineFileStore() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let result = SupatermSettingsMutationResult(
      path: "/tmp/settings.toml",
      key: "logging.verbose_enabled",
      oldValue: "false",
      value: "true",
      defaultValue: "false",
      isDefault: false
    )

    try await withSocketRuntime(
      replying: { request, _ in try .ok(id: request.id, encodableResult: result) },
      run: { endpoint in
        let set = try cli.run(
          ["config", "set", "logging.verbose_enabled", "true", "--socket", endpoint.path]
        )

        #expect(set.exitCode == 0)
        #expect(!FileManager.default.fileExists(atPath: cli.settingsURL.path))
      }
    )
  }
}

private let appearanceModeEntry = SupatermSettingsEntry(
  key: "appearance.mode",
  value: "system",
  defaultValue: "dark",
  valueKind: .string,
  allowedValues: ["system", "light", "dark"],
  isDefault: false
)
