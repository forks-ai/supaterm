import Foundation
import SupatermCLIShared
import Testing

struct SPConfigOfflineCommandTests {
  @Test
  func setGetListAndResetRoundTripThroughTheSettingsFile() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let set = try cli.run(["config", "set", "logging.verbose_enabled", "true"])
    #expect(
      set
        == SPCLIResult(
          exitCode: 0,
          stdout: """
            Updated logging.verbose_enabled: false -> true
            warning: Verbose logging changes apply next time Supaterm starts.

            """,
          stderr: ""
        )
    )
    #expect(
      try String(contentsOf: cli.settingsURL, encoding: .utf8).trimmingCharacters(in: .newlines)
        == """
        [logging]
        verbose_enabled = true
        """
    )

    #expect(try cli.run(["config", "get", "logging.verbose_enabled"]).stdout == "logging.verbose_enabled = true\n")
    #expect(
      try cli.run(["config", "get", "logging.verbose_enabled", "--plain"]).stdout
        == "logging.verbose_enabled\ttrue\n"
    )
    #expect(try cli.run(["config", "list", "--changed", "--plain"]).stdout == "logging.verbose_enabled\ttrue\n")
    #expect(try cli.run(["config", "list", "--plain"]).stdout.split(separator: "\n").count == 11)

    let reset = try cli.run(["config", "reset", "logging.verbose_enabled"])
    #expect(
      reset.stdout == """
        Reset logging.verbose_enabled: true -> false
        warning: Verbose logging changes apply next time Supaterm starts.

        """
    )
    #expect(try String(contentsOf: cli.settingsURL, encoding: .utf8).isEmpty)
    #expect(try cli.run(["config", "list", "--changed"]).stdout == "No changed settings.\n")
  }

  @Test
  func getReportsTheSettingsFileFromTheStateHome() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let path = try cli.run(["config", "path"])
    let json = try cli.run(["config", "get", "appearance.mode", "--json"])

    #expect(path.stdout == cli.settingsURL.path + "\n")
    #expect(
      try decodedCLIJSON(SupatermSettingsGetResult.self, from: json)
        == SupatermSettingsGetResult(
          path: cli.settingsURL.path,
          entry: SupatermSettingsEntry(
            key: "appearance.mode",
            value: "dark",
            defaultValue: "dark",
            valueKind: .string,
            allowedValues: ["system", "light", "dark"],
            isDefault: true
          )
        )
    )
  }

  @Test
  func unknownKeysAndInvalidValuesFailWithoutWritingTheSettingsFile() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let unknown = try cli.run(["config", "get", "terminal.confirm_quit"])
    let invalid = try cli.run(["config", "set", "appearance.mode", "sepia"])

    #expect(unknown.exitCode == 1)
    #expect(unknown.stderr == "Error: Unknown config key `terminal.confirm_quit`.\n")
    #expect(invalid.exitCode == 1)
    #expect(
      invalid.stderr
        == "Error: Invalid value `sepia` for `appearance.mode`. Expected one of: system, light, dark.\n"
    )
    #expect(!FileManager.default.fileExists(atPath: cli.settingsURL.path))
  }

  @Test
  func validateReportsMissingValidAndInvalidDefaultConfigs() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let path = cli.settingsURL.path

    let missing = try cli.run(["config", "validate"])
    #expect(missing.exitCode == 0)
    #expect(missing.stdout == "No config file at \(path). Defaults are in effect.\n")
    #expect(try cli.run(["config", "validate", "--plain"]).stdout == "missing\t\(path)\n")
    #expect(
      try decodedCLIJSON(
        SupatermSettingsValidationResult.self,
        from: cli.run(["config", "validate", "--json"])
      )
        == SupatermSettingsValidationResult(path: path, status: .missing, warnings: [], errors: [])
    )

    try Data(
      """
      [appearance]
      mode = "light"
      extra = 1
      """.utf8
    )
    .write(to: cli.settingsURL)

    let warned = try cli.run(["config", "validate"])
    #expect(warned.exitCode == 0)
    #expect(
      warned.stdout == """
        Valid config: \(path)
        warning: Unknown config key `appearance.extra`.

        """
    )
    #expect(
      try cli.run(["config", "validate", "--plain"]).stdout == """
        valid\t\(path)
        warning\tUnknown config key `appearance.extra`.

        """
    )

    try Data(#"[updates]\#nchannel = "beta"\#n"#.utf8).write(to: cli.settingsURL)

    let invalid = try cli.run(["config", "validate"])
    #expect(invalid.exitCode == 1)
    #expect(invalid.stdout.hasPrefix("Invalid config: \(path)\nerror: "))
    #expect(
      try decodedCLIJSON(
        SupatermSettingsValidationResult.self,
        from: cli.run(["config", "validate", "--json"])
      ).status == .invalid
    )
    #expect(try cli.run(["config", "validate", "--quiet"]) == SPCLIResult(exitCode: 1, stdout: "", stderr: ""))
  }

  @Test
  func validateWithExplicitPathFailsOnMissingAndMalformedFiles() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let validURL = cli.rootURL.appendingPathComponent("valid.toml", isDirectory: false)
    let malformedURL = cli.rootURL.appendingPathComponent("malformed.toml", isDirectory: false)
    let missingURL = cli.rootURL.appendingPathComponent("missing.toml", isDirectory: false)
    try Data().write(to: validURL)
    try Data("appearance = [".utf8).write(to: malformedURL)

    let valid = try cli.run(["config", "validate", "--path", validURL.path])
    #expect(valid == SPCLIResult(exitCode: 0, stdout: "Valid config: \(validURL.path)\n", stderr: ""))

    let malformed = try cli.run(["config", "validate", "--path", malformedURL.path, "--plain"])
    #expect(malformed.exitCode == 1)
    #expect(malformed.stdout.hasPrefix("invalid\t\(malformedURL.path)\nerror\t"))

    let missing = try cli.run(["config", "validate", "--path", missingURL.path])
    #expect(missing.exitCode == 1)
    #expect(
      missing.stdout == """
        Missing config: \(missingURL.path)
        error: Config file not found at \(missingURL.path).

        """
    )

    let empty = try cli.run(["config", "validate", "--path", ""])
    #expect(empty.exitCode == 64)
    #expect(
      empty.stderr == """
        Error: --path must not be empty.
        Usage: sp <subcommand>
          See 'sp --help' for more information.

        """
    )
  }

  @Test
  func settingsFileStoreIgnoresTheCLITestHomeWithoutAStateHome() throws {
    var cli = try SPCLIHarness()
    defer { cli.remove() }
    cli.environment[SupatermCLIEnvironment.stateHomeKey] = nil

    let path = try cli.run(["config", "path"])
    let validate = try cli.run(["config", "validate", "--plain"])

    #expect(
      path.stdout
        == FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".config/supaterm/settings.toml", isDirectory: false).path + "\n"
    )
    #expect(
      validate.stdout.hasSuffix(
        "\t\(cli.homeURL.appendingPathComponent(".config/supaterm/settings.toml", isDirectory: false).path)\n"
      )
    )
  }
}

func decodedCLIJSON<T: Decodable>(_ type: T.Type, from result: SPCLIResult) throws -> T {
  let data = try #require(result.stdout.data(using: .utf8))
  let decoder = JSONDecoder()
  decoder.dateDecodingStrategy = .iso8601
  return try decoder.decode(type, from: data)
}
