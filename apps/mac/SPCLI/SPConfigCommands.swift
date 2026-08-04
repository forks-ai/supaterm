import ArgumentParser
import Foundation
import SupatermCLIShared

extension SP {
  struct Config: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "config",
      abstract: "Inspect, edit, and validate Supaterm configuration.",
      discussion: SPHelp.configDiscussion,
      subcommands: [
        PathConfig.self,
        ListConfig.self,
        GetConfig.self,
        SetConfig.self,
        ResetConfig.self,
        ValidateConfig.self,
      ]
    )

    mutating func run() throws {
      print(Self.helpMessage())
    }
  }

  struct PathConfig: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "path",
      abstract: "Print the Supaterm settings file path."
    )

    @OptionGroup
    var output: SPOutputOptions

    mutating func run() throws {
      applyOutputStyle(output)
      let result = SupatermSettingsPathResult(path: SupatermStateRoot.settingsFileURL().path)
      try emitCommandResult(
        result,
        options: output,
        plain: result.path,
        human: result.path
      )
    }
  }

  struct ListConfig: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "list",
      abstract: "List Supaterm settings."
    )

    @Flag(name: .long, help: "Only list settings that differ from defaults.")
    var changed = false

    @OptionGroup
    var options: SPCommandOptions

    mutating func run() throws {
      try runControlCommand(
        options: options,
        request: { _ in try .settingsList(SupatermSettingsListRequest(changedOnly: changed)) },
        as: SupatermSettingsListResult.self,
        plain: { renderPlain($0) },
        human: { renderHuman($0) }
      )
    }
  }

  struct GetConfig: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "get",
      abstract: "Print one Supaterm setting."
    )

    @Argument(help: "Settings key.")
    var key: String

    @OptionGroup
    var options: SPCommandOptions

    mutating func run() throws {
      try runControlCommand(
        options: options,
        request: { _ in try .settingsGet(SupatermSettingsGetRequest(key: key)) },
        as: SupatermSettingsGetResult.self,
        plain: { "\($0.entry.key)\t\($0.entry.value)" },
        human: { "\($0.entry.key) = \($0.entry.value)\(warningSuffix($0.warnings))" }
      )
    }
  }

  struct SetConfig: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "set",
      abstract: "Set one Supaterm setting."
    )

    @Argument(help: "Settings key.")
    var key: String

    @Argument(help: "Settings value.")
    var value: String

    @OptionGroup
    var options: SPCommandOptions

    mutating func run() throws {
      try runControlCommand(
        options: options,
        request: { _ in try .settingsSet(SupatermSettingsSetRequest(key: key, value: value)) },
        as: SupatermSettingsMutationResult.self,
        plain: { "\($0.key)\t\($0.oldValue)\t\($0.value)" },
        human: { "Updated \($0.key): \($0.oldValue) -> \($0.value)\(warningSuffix($0.warnings))" }
      )
    }
  }

  struct ResetConfig: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "reset",
      abstract: "Reset one Supaterm setting to its default."
    )

    @Argument(help: "Settings key.")
    var key: String

    @OptionGroup
    var options: SPCommandOptions

    mutating func run() throws {
      try runControlCommand(
        options: options,
        request: { _ in try .settingsReset(SupatermSettingsResetRequest(key: key)) },
        as: SupatermSettingsMutationResult.self,
        plain: { "\($0.key)\t\($0.oldValue)\t\($0.value)" },
        human: { "Reset \($0.key): \($0.oldValue) -> \($0.value)\(warningSuffix($0.warnings))" }
      )
    }
  }

  struct ValidateConfig: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "validate",
      abstract: "Validate Supaterm configuration.",
      discussion: SPHelp.validateConfigDiscussion
    )

    @Option(name: .long, help: "Validate a specific config file instead of the default path.")
    var path: String?

    @OptionGroup
    var options: SPCommandOptions

    mutating func run() throws {
      applyOutputStyle(options.output)
      let explicitPath = try resolvedConfigPath(path)
      let client = try socketClient(
        path: options.connection.explicitSocketPath,
        instance: options.connection.instance
      )
      let response = try client.send(
        try .settingsValidate(SupatermSettingsValidateRequest(path: explicitPath?.path))
      )
      guard response.ok else {
        throw ValidationError(response.error?.message ?? "Supaterm socket request failed.")
      }
      let result = try response.decodeResult(SupatermSettingsValidationResult.self)

      guard !options.output.quiet else {
        if shouldFail(result: result, explicitPath: explicitPath) {
          throw ExitCode.failure
        }
        return
      }

      switch options.output.mode {
      case .json:
        print(try jsonString(result))
      case .plain:
        print(renderPlain(result))
      case .human:
        print(renderHuman(result))
      }

      if shouldFail(result: result, explicitPath: explicitPath) {
        throw ExitCode.failure
      }
    }
  }
}

private func shouldFail(
  result: SupatermSettingsValidationResult,
  explicitPath: URL?
) -> Bool {
  if explicitPath != nil, result.status == .missing {
    return true
  }
  return result.isFailure
}

private func resolvedConfigPath(_ path: String?) throws -> URL? {
  guard let path else { return nil }
  let trimmed = path.trimmingCharacters(in: .whitespacesAndNewlines)
  guard !trimmed.isEmpty else {
    throw ValidationError("--path must not be empty.")
  }
  let expandedPath = expandCLIHomePath(trimmed)
  let url: URL
  if expandedPath.hasPrefix("/") {
    url = URL(fileURLWithPath: expandedPath, isDirectory: false)
  } else {
    url = URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
      .appendingPathComponent(expandedPath, isDirectory: false)
  }
  return url.standardizedFileURL
}

private func renderPlain(_ result: SupatermSettingsValidationResult) -> String {
  let lines =
    [
      "\(result.status.rawValue)\t\(result.path)"
    ] + result.warnings.map { "warning\t\($0)" } + result.errors.map { "error\t\($0)" }
  return lines.joined(separator: "\n")
}

private func renderPlain(_ result: SupatermSettingsListResult) -> String {
  let lines = result.entries.map { "\($0.key)\t\($0.value)" }
  return (lines + result.warnings.map { "warning\t\($0)" }).joined(separator: "\n")
}

private func renderHuman(_ result: SupatermSettingsListResult) -> String {
  let settingLines =
    result.entries.isEmpty
    ? ["No changed settings."]
    : result.entries.map { "\($0.key) = \($0.value)" }
  return (settingLines + result.warnings.map { "warning: \($0)" }).joined(separator: "\n")
}

private func warningSuffix(_ warnings: [String]) -> String {
  guard !warnings.isEmpty else { return "" }
  return "\n" + warnings.map { "warning: \($0)" }.joined(separator: "\n")
}

private func renderHuman(_ result: SupatermSettingsValidationResult) -> String {
  let headline: String
  switch result.status {
  case .valid:
    headline = "Valid config: \(result.path)"
  case .missing:
    headline =
      result.errors.isEmpty
      ? "No config file at \(result.path). Defaults are in effect."
      : "Missing config: \(result.path)"
  case .invalid:
    headline = "Invalid config: \(result.path)"
  }

  let warningLines = result.warnings.map { "warning: \($0)" }
  let errorLines = result.errors.map { "error: \($0)" }
  return ([headline] + warningLines + errorLines).joined(separator: "\n")
}
