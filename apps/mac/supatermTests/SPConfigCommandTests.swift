import Darwin
import Foundation
import SupatermCLIShared
import Testing

@testable import SPCLI

struct SPConfigCommandTests {
  @Test
  func validateRendersMissingValidAndInvalidResultsInEveryOutputMode() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let log = SPSocketRequestLog()
    let results = SPValidationResultQueue([
      SupatermSettingsValidationResult(path: settingsPath, status: .missing, warnings: [], errors: []),
      SupatermSettingsValidationResult(path: settingsPath, status: .missing, warnings: [], errors: []),
      SupatermSettingsValidationResult(
        path: settingsPath,
        status: .valid,
        warnings: ["Unknown config key `appearance.extra`."],
        errors: []
      ),
      SupatermSettingsValidationResult(
        path: settingsPath,
        status: .valid,
        warnings: ["Unknown config key `appearance.extra`."],
        errors: []
      ),
      SupatermSettingsValidationResult(
        path: settingsPath,
        status: .invalid,
        warnings: [],
        errors: ["Invalid value `beta` for `updates.channel`."]
      ),
      SupatermSettingsValidationResult(
        path: settingsPath,
        status: .invalid,
        warnings: [],
        errors: ["Invalid value `beta` for `updates.channel`."]
      ),
    ])

    try await withSocketRuntime(
      replying: { request, _ in
        log.record(request)
        return try .ok(id: request.id, encodableResult: results.next())
      },
      run: { endpoint in
        let socket = ["--socket", endpoint.path]
        let missing = try cli.run(["config", "validate"] + socket)
        let missingPlain = try cli.run(["config", "validate", "--plain"] + socket)
        let warned = try cli.run(["config", "validate"] + socket)
        let warnedPlain = try cli.run(["config", "validate", "--plain"] + socket)
        let invalid = try cli.run(["config", "validate", "--json"] + socket)
        let quiet = try cli.run(["config", "validate", "--quiet"] + socket)

        #expect(
          missing
            == SPCLIResult(
              exitCode: 0,
              stdout: "No config file at \(settingsPath). Defaults are in effect.\n",
              stderr: ""
            )
        )
        #expect(missingPlain.stdout == "missing\t\(settingsPath)\n")
        #expect(
          warned
            == SPCLIResult(
              exitCode: 0,
              stdout: """
                Valid config: \(settingsPath)
                warning: Unknown config key `appearance.extra`.

                """,
              stderr: ""
            )
        )
        #expect(
          warnedPlain.stdout == """
            valid\t\(settingsPath)
            warning\tUnknown config key `appearance.extra`.

            """
        )
        #expect(invalid.exitCode == 1)
        #expect(
          invalid.stdout == """
            {"errors":["Invalid value `beta` for `updates.channel`."],"path":"\\/tmp\\/settings.toml",\
            "status":"invalid","warnings":[]}

            """
        )
        #expect(quiet == SPCLIResult(exitCode: 1, stdout: "", stderr: ""))
      }
    )

    #expect(log.requests.map(\.method) == Array(repeating: SupatermSocketMethod.appSettingsValidate, count: 6))
    #expect(try log.requests.map { try jsonString($0.params) } == Array(repeating: "{}", count: 6))
  }

  @Test
  func validateResolvesTildeAndRelativePathsBeforeSendingThem() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let log = SPSocketRequestLog()
    let tildePath = cli.homeURL.appendingPathComponent("tilde.toml", isDirectory: false).path
    let relativePath = physicalPath(cli.homeURL) + "/relative.toml"

    try await withSocketRuntime(
      replying: { request, _ in
        log.record(request)
        let path = try request.decodeParams(SupatermSettingsValidateRequest.self).path ?? ""
        return try .ok(
          id: request.id,
          encodableResult: SupatermSettingsValidationResult(
            path: path,
            status: .valid,
            warnings: [],
            errors: []
          )
        )
      },
      run: { endpoint in
        let socket = ["--socket", endpoint.path]
        let absolute = try cli.run(["config", "validate", "--path", "/etc/supaterm.toml"] + socket)
        let tilde = try cli.run(["config", "validate", "--path", "~/tilde.toml"] + socket)
        let relative = try cli.run(["config", "validate", "--path", "relative.toml"] + socket)

        #expect(absolute.stdout == "Valid config: /etc/supaterm.toml\n")
        #expect(tilde.stdout == "Valid config: \(tildePath)\n")
        #expect(relative.stdout == "Valid config: \(relativePath)\n")
      }
    )

    #expect(
      try log.requests.map { try jsonString($0.params) } == [
        #"{"path":"\/etc\/supaterm.toml"}"#,
        try jsonString(SupatermSettingsValidateRequest(path: tildePath)),
        try jsonString(SupatermSettingsValidateRequest(path: relativePath)),
      ]
    )
  }

  @Test
  func validateWithAnExplicitPathFailsWhenTheFileIsMissing() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    try await withSocketRuntime(
      replying: { request, _ in
        try .ok(
          id: request.id,
          encodableResult: SupatermSettingsValidationResult(
            path: "/tmp/missing.toml",
            status: .missing,
            warnings: [],
            errors: ["Config file not found at /tmp/missing.toml."]
          )
        )
      },
      run: { endpoint in
        let missing = try cli.run(
          ["config", "validate", "--path", "/tmp/missing.toml", "--socket", endpoint.path]
        )

        #expect(missing.exitCode == 1)
        #expect(
          missing.stdout == """
            Missing config: /tmp/missing.toml
            error: Config file not found at /tmp/missing.toml.

            """
        )
      }
    )
  }

  @Test
  func validateRejectsAnEmptyPathBeforeSendingARequest() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let log = SPSocketRequestLog()

    try await withSocketRuntime(
      replying: { request, _ in
        log.record(request)
        return .error(id: request.id, code: "invalid_request", message: "unreachable")
      },
      run: { endpoint in
        let empty = try cli.run(["config", "validate", "--path", "", "--socket", endpoint.path])

        #expect(empty.exitCode == 64)
        #expect(
          empty.stderr == """
            Error: --path must not be empty.
            Usage: sp <subcommand>
              See 'sp --help' for more information.

            """
        )
      }
    )

    #expect(log.requests.isEmpty)
  }

  @Test
  func pathPrintsTheSettingsFileWithoutASocket() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let path = try cli.run(["config", "path"])
    let json = try cli.run(["config", "path", "--json"])

    #expect(path == SPCLIResult(exitCode: 0, stdout: cli.settingsURL.path + "\n", stderr: ""))
    #expect(
      try decodedCLIJSON(SupatermSettingsPathResult.self, from: json)
        == SupatermSettingsPathResult(path: cli.settingsURL.path)
    )
  }

  @Test
  func pathIgnoresTheCLITestHomeWithoutAStateHome() throws {
    var cli = try SPCLIHarness()
    defer { cli.remove() }
    cli.environment[SupatermCLIEnvironment.stateHomeKey] = nil

    let path = try cli.run(["config", "path"])

    #expect(
      path.stdout
        == FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/supaterm/settings.toml", isDirectory: false).path + "\n"
    )
  }

  @Test(
    arguments: [
      ["config", "get", "appearance.mode"],
      ["config", "set", "appearance.mode", "light"],
      ["config", "list"],
      ["config", "reset", "appearance.mode"],
      ["config", "validate"],
    ]
  )
  func configCommandsFailWithoutAReachableInstance(arguments: [String]) throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let result = try cli.run(arguments)

    #expect(result.exitCode == 64)
    #expect(result.stdout.isEmpty)
    #expect(
      result.stderr == """
        Error: No reachable Supaterm instance was found.
        Usage: sp <subcommand>
          See 'sp --help' for more information.

        """
    )
    #expect(!FileManager.default.fileExists(atPath: cli.settingsURL.path))
  }
}

private let settingsPath = "/tmp/settings.toml"

private func physicalPath(_ url: URL) -> String {
  guard let resolved = realpath(url.path, nil) else { return url.path }
  defer { free(resolved) }
  return String(cString: resolved)
}

private nonisolated final class SPValidationResultQueue: @unchecked Sendable {
  private let lock = NSLock()
  private var results: [SupatermSettingsValidationResult]

  init(_ results: [SupatermSettingsValidationResult]) {
    self.results = results
  }

  func next() -> SupatermSettingsValidationResult {
    lock.lock()
    defer { lock.unlock() }
    return results.removeFirst()
  }
}

private func decodedCLIJSON<T: Decodable>(_ type: T.Type, from result: SPCLIResult) throws -> T {
  let data = try #require(result.stdout.data(using: .utf8))
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  return try decoder.decode(type, from: data)
}
