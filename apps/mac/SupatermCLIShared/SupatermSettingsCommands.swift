import Foundation

public enum SupatermSettingsCommandError: Error, Equatable, LocalizedError, Sendable {
  case invalidKey(String)
  case invalidValue(key: String, value: String, allowedValues: [String])

  public var errorDescription: String? {
    switch self {
    case .invalidKey(let key):
      return "Unknown config key `\(key)`."
    case .invalidValue(let key, let value, let allowedValues):
      return "Invalid value `\(value)` for `\(key)`. Expected one of: \(allowedValues.joined(separator: ", "))."
    }
  }
}

public enum SupatermSettingsValueKind: String, Codable, Equatable, Sendable {
  case bool
  case string
}

public enum SupatermSettingsKey: String, CaseIterable, Codable, Equatable, Sendable {
  case appearanceMode = "appearance.mode"
  case terminalRestoreLayout = "terminal.restore_layout"
  case terminalZmxSessionsEnabled = "terminal.zmx_sessions_enabled"
  case notificationsSystemNotifications = "notifications.system_notifications"
  case notificationsGlowingPaneRing = "notifications.glowing_pane_ring"
  case codingAgentsShowPanel = "coding_agents.show_panel"
  case codingAgentsShowIcons = "coding_agents.show_icons"
  case codingAgentsShowSpinner = "coding_agents.show_spinner"
  case privacyAnalyticsEnabled = "privacy.analytics_enabled"
  case privacyCrashReportsEnabled = "privacy.crash_reports_enabled"
  case updatesChannel = "updates.channel"
  case loggingVerboseEnabled = "logging.verbose_enabled"

  public init(path: String) throws {
    guard let key = Self(rawValue: path) else {
      throw SupatermSettingsCommandError.invalidKey(path)
    }
    self = key
  }

  public var valueKind: SupatermSettingsValueKind {
    switch self {
    case .appearanceMode,
      .updatesChannel:
      return .string
    case .terminalRestoreLayout,
      .terminalZmxSessionsEnabled,
      .notificationsSystemNotifications,
      .notificationsGlowingPaneRing,
      .codingAgentsShowPanel,
      .codingAgentsShowIcons,
      .codingAgentsShowSpinner,
      .privacyAnalyticsEnabled,
      .privacyCrashReportsEnabled,
      .loggingVerboseEnabled:
      return .bool
    }
  }

  public var allowedValues: [String] {
    switch self {
    case .appearanceMode:
      return AppearanceMode.allCases.map(\.rawValue)
    case .updatesChannel:
      return UpdateChannel.allCases.map(\.rawValue)
    case .terminalRestoreLayout,
      .terminalZmxSessionsEnabled,
      .notificationsSystemNotifications,
      .notificationsGlowingPaneRing,
      .codingAgentsShowPanel,
      .codingAgentsShowIcons,
      .codingAgentsShowSpinner,
      .privacyAnalyticsEnabled,
      .privacyCrashReportsEnabled,
      .loggingVerboseEnabled:
      return ["true", "false"]
    }
  }

  public func value(in settings: SupatermSettings) -> String {
    switch self {
    case .appearanceMode:
      return settings.appearanceMode.rawValue
    case .terminalRestoreLayout:
      return string(settings.restoreTerminalLayoutEnabled)
    case .terminalZmxSessionsEnabled:
      return string(settings.zmxSessionsEnabled)
    case .notificationsSystemNotifications:
      return string(settings.systemNotificationsEnabled)
    case .notificationsGlowingPaneRing:
      return string(settings.glowingPaneRingEnabled)
    case .codingAgentsShowPanel:
      return string(settings.codingAgentsShowPanel)
    case .codingAgentsShowIcons:
      return string(settings.codingAgentsShowIcons)
    case .codingAgentsShowSpinner:
      return string(settings.codingAgentsShowSpinner)
    case .privacyAnalyticsEnabled:
      return string(settings.analyticsEnabled)
    case .privacyCrashReportsEnabled:
      return string(settings.crashReportsEnabled)
    case .updatesChannel:
      return settings.updateChannel.rawValue
    case .loggingVerboseEnabled:
      return string(settings.verboseLoggingEnabled)
    }
  }

  public var defaultValue: String {
    value(in: .default)
  }

  public func set(_ rawValue: String, in settings: inout SupatermSettings) throws {
    switch self {
    case .appearanceMode:
      settings.appearanceMode = try parsedEnum(AppearanceMode.self, rawValue: rawValue)
    case .terminalRestoreLayout:
      settings.restoreTerminalLayoutEnabled = try parsedBool(rawValue)
    case .terminalZmxSessionsEnabled:
      settings.zmxSessionsEnabled = try parsedBool(rawValue)
    case .notificationsSystemNotifications:
      settings.systemNotificationsEnabled = try parsedBool(rawValue)
    case .notificationsGlowingPaneRing:
      settings.glowingPaneRingEnabled = try parsedBool(rawValue)
    case .codingAgentsShowPanel:
      settings.codingAgentsShowPanel = try parsedBool(rawValue)
    case .codingAgentsShowIcons:
      settings.codingAgentsShowIcons = try parsedBool(rawValue)
    case .codingAgentsShowSpinner:
      settings.codingAgentsShowSpinner = try parsedBool(rawValue)
    case .privacyAnalyticsEnabled:
      settings.analyticsEnabled = try parsedBool(rawValue)
    case .privacyCrashReportsEnabled:
      settings.crashReportsEnabled = try parsedBool(rawValue)
    case .updatesChannel:
      settings.updateChannel = try parsedEnum(UpdateChannel.self, rawValue: rawValue)
    case .loggingVerboseEnabled:
      settings.verboseLoggingEnabled = try parsedBool(rawValue)
    }
  }

  public func reset(in settings: inout SupatermSettings) {
    switch self {
    case .appearanceMode:
      settings.appearanceMode = SupatermSettings.default.appearanceMode
    case .terminalRestoreLayout:
      settings.restoreTerminalLayoutEnabled = SupatermSettings.default.restoreTerminalLayoutEnabled
    case .terminalZmxSessionsEnabled:
      settings.zmxSessionsEnabled = SupatermSettings.default.zmxSessionsEnabled
    case .notificationsSystemNotifications:
      settings.systemNotificationsEnabled = SupatermSettings.default.systemNotificationsEnabled
    case .notificationsGlowingPaneRing:
      settings.glowingPaneRingEnabled = SupatermSettings.default.glowingPaneRingEnabled
    case .codingAgentsShowPanel:
      settings.codingAgentsShowPanel = SupatermSettings.default.codingAgentsShowPanel
    case .codingAgentsShowIcons:
      settings.codingAgentsShowIcons = SupatermSettings.default.codingAgentsShowIcons
    case .codingAgentsShowSpinner:
      settings.codingAgentsShowSpinner = SupatermSettings.default.codingAgentsShowSpinner
    case .privacyAnalyticsEnabled:
      settings.analyticsEnabled = SupatermSettings.default.analyticsEnabled
    case .privacyCrashReportsEnabled:
      settings.crashReportsEnabled = SupatermSettings.default.crashReportsEnabled
    case .updatesChannel:
      settings.updateChannel = SupatermSettings.default.updateChannel
    case .loggingVerboseEnabled:
      settings.verboseLoggingEnabled = SupatermSettings.default.verboseLoggingEnabled
    }
  }

  public func mutationWarnings(isLive: Bool) -> [String] {
    switch self {
    case .terminalZmxSessionsEnabled:
      return ["Restart Supaterm for zmx session changes to take effect."]
    case .notificationsSystemNotifications:
      return ["macOS notification permission may still be required."]
    case .updatesChannel where !isLive:
      return ["Update channel changes apply next time Supaterm starts."]
    case .loggingVerboseEnabled where !isLive:
      return ["Verbose logging changes apply next time Supaterm starts."]
    default:
      return []
    }
  }

  private func string(_ value: Bool) -> String {
    value ? "true" : "false"
  }

  private func parsedBool(_ rawValue: String) throws -> Bool {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    switch value {
    case "true":
      return true
    case "false":
      return false
    default:
      throw SupatermSettingsCommandError.invalidValue(
        key: self.rawValue,
        value: rawValue,
        allowedValues: allowedValues
      )
    }
  }

  private func parsedEnum<Value: RawRepresentable>(
    _ type: Value.Type,
    rawValue: String
  ) throws -> Value where Value.RawValue == String {
    let value = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    guard let parsed = Value(rawValue: value) else {
      throw SupatermSettingsCommandError.invalidValue(
        key: self.rawValue,
        value: rawValue,
        allowedValues: allowedValues
      )
    }
    return parsed
  }
}

public struct SupatermSettingsEntry: Codable, Equatable, Sendable {
  public let key: String
  public let value: String
  public let defaultValue: String
  public let valueKind: SupatermSettingsValueKind
  public let allowedValues: [String]
  public let isDefault: Bool

  public init(
    key: String,
    value: String,
    defaultValue: String,
    valueKind: SupatermSettingsValueKind,
    allowedValues: [String],
    isDefault: Bool
  ) {
    self.key = key
    self.value = value
    self.defaultValue = defaultValue
    self.valueKind = valueKind
    self.allowedValues = allowedValues
    self.isDefault = isDefault
  }
}

public struct SupatermSettingsPathResult: Codable, Equatable, Sendable {
  public let path: String

  public init(path: String) {
    self.path = path
  }
}

public struct SupatermSettingsGetRequest: Codable, Equatable, Sendable {
  public let key: String

  public init(key: String) {
    self.key = key
  }
}

public struct SupatermSettingsListRequest: Codable, Equatable, Sendable {
  public let changedOnly: Bool

  public init(changedOnly: Bool = false) {
    self.changedOnly = changedOnly
  }
}

public struct SupatermSettingsSetRequest: Codable, Equatable, Sendable {
  public let key: String
  public let value: String

  public init(key: String, value: String) {
    self.key = key
    self.value = value
  }
}

public struct SupatermSettingsResetRequest: Codable, Equatable, Sendable {
  public let key: String

  public init(key: String) {
    self.key = key
  }
}

public struct SupatermSettingsListResult: Codable, Equatable, Sendable {
  public let path: String
  public let entries: [SupatermSettingsEntry]
  public let warnings: [String]

  public init(
    path: String,
    entries: [SupatermSettingsEntry],
    warnings: [String] = []
  ) {
    self.path = path
    self.entries = entries
    self.warnings = warnings
  }
}

public struct SupatermSettingsGetResult: Codable, Equatable, Sendable {
  public let path: String
  public let entry: SupatermSettingsEntry
  public let warnings: [String]

  public init(
    path: String,
    entry: SupatermSettingsEntry,
    warnings: [String] = []
  ) {
    self.path = path
    self.entry = entry
    self.warnings = warnings
  }
}

public struct SupatermSettingsMutationResult: Codable, Equatable, Sendable {
  public let path: String
  public let key: String
  public let oldValue: String
  public let value: String
  public let defaultValue: String
  public let isDefault: Bool
  public let warnings: [String]

  public init(
    path: String,
    key: String,
    oldValue: String,
    value: String,
    defaultValue: String,
    isDefault: Bool,
    warnings: [String] = []
  ) {
    self.path = path
    self.key = key
    self.oldValue = oldValue
    self.value = value
    self.defaultValue = defaultValue
    self.isDefault = isDefault
    self.warnings = warnings
  }
}

public enum SupatermSettingsRegistry {
  public static func entry(
    for key: SupatermSettingsKey,
    settings: SupatermSettings
  ) -> SupatermSettingsEntry {
    let value = key.value(in: settings)
    return SupatermSettingsEntry(
      key: key.rawValue,
      value: value,
      defaultValue: key.defaultValue,
      valueKind: key.valueKind,
      allowedValues: key.allowedValues,
      isDefault: value == key.defaultValue
    )
  }

  public static func list(
    settings: SupatermSettings,
    path: String,
    changedOnly: Bool,
    warnings: [String] = []
  ) -> SupatermSettingsListResult {
    let entries = SupatermSettingsKey.allCases
      .map { entry(for: $0, settings: settings) }
      .filter { !changedOnly || !$0.isDefault }
    return SupatermSettingsListResult(path: path, entries: entries, warnings: warnings)
  }

  public static func get(
    key rawKey: String,
    settings: SupatermSettings,
    path: String,
    warnings: [String] = []
  ) throws -> SupatermSettingsGetResult {
    let key = try SupatermSettingsKey(path: rawKey)
    return SupatermSettingsGetResult(
      path: path,
      entry: entry(for: key, settings: settings),
      warnings: warnings
    )
  }

  public static func set(
    _ request: SupatermSettingsSetRequest,
    settings: SupatermSettings,
    path: String,
    isLive: Bool
  ) throws -> (settings: SupatermSettings, result: SupatermSettingsMutationResult) {
    let key = try SupatermSettingsKey(path: request.key)
    let oldValue = key.value(in: settings)
    var updatedSettings = settings
    try key.set(request.value, in: &updatedSettings)
    let value = key.value(in: updatedSettings)
    return (
      updatedSettings,
      SupatermSettingsMutationResult(
        path: path,
        key: key.rawValue,
        oldValue: oldValue,
        value: value,
        defaultValue: key.defaultValue,
        isDefault: value == key.defaultValue,
        warnings: oldValue == value ? [] : key.mutationWarnings(isLive: isLive)
      )
    )
  }

  public static func reset(
    _ request: SupatermSettingsResetRequest,
    settings: SupatermSettings,
    path: String,
    isLive: Bool
  ) throws -> (settings: SupatermSettings, result: SupatermSettingsMutationResult) {
    let key = try SupatermSettingsKey(path: request.key)
    let oldValue = key.value(in: settings)
    var updatedSettings = settings
    key.reset(in: &updatedSettings)
    let value = key.value(in: updatedSettings)
    return (
      updatedSettings,
      SupatermSettingsMutationResult(
        path: path,
        key: key.rawValue,
        oldValue: oldValue,
        value: value,
        defaultValue: key.defaultValue,
        isDefault: true,
        warnings: oldValue == value ? [] : key.mutationWarnings(isLive: isLive)
      )
    )
  }
}

public struct SupatermSettingsFileStore {
  private let environment: [String: String]
  private let fileManager: FileManager
  private let homeDirectoryURL: URL

  public init(
    homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
    environment: [String: String] = ProcessInfo.processInfo.environment,
    fileManager: FileManager = .default
  ) {
    self.environment = environment
    self.fileManager = fileManager
    self.homeDirectoryURL = homeDirectoryURL
  }

  public var settingsURL: URL {
    SupatermSettings.defaultURL(
      homeDirectoryPath: homeDirectoryURL.path,
      environment: environment
    )
  }

  public func path() -> SupatermSettingsPathResult {
    SupatermSettingsPathResult(path: settingsURL.path)
  }

  public func list(changedOnly: Bool = false) throws -> SupatermSettingsListResult {
    let loaded = try load()
    return SupatermSettingsRegistry.list(
      settings: loaded.settings,
      path: settingsURL.path,
      changedOnly: changedOnly,
      warnings: loaded.warnings
    )
  }

  public func get(key: String) throws -> SupatermSettingsGetResult {
    let loaded = try load()
    return try SupatermSettingsRegistry.get(
      key: key,
      settings: loaded.settings,
      path: settingsURL.path,
      warnings: loaded.warnings
    )
  }

  public func set(_ request: SupatermSettingsSetRequest) throws -> SupatermSettingsMutationResult {
    let loaded = try load()
    let edit = try SupatermSettingsRegistry.set(
      request,
      settings: loaded.settings,
      path: settingsURL.path,
      isLive: false
    )
    try save(edit.settings)
    return edit.result
  }

  public func reset(_ request: SupatermSettingsResetRequest) throws -> SupatermSettingsMutationResult {
    let loaded = try load()
    let edit = try SupatermSettingsRegistry.reset(
      request,
      settings: loaded.settings,
      path: settingsURL.path,
      isLive: false
    )
    try save(edit.settings)
    return edit.result
  }

  private func load() throws -> (settings: SupatermSettings, warnings: [String]) {
    guard fileManager.fileExists(atPath: settingsURL.path) else {
      return (.default, [])
    }
    let data = try Data(contentsOf: settingsURL)
    return (
      try SupatermSettingsCodec.decode(data),
      try SupatermSettingsCodec.unknownKeyWarnings(in: data)
    )
  }

  private func save(_ settings: SupatermSettings) throws {
    let data = try SupatermSettingsCodec.encode(settings)
    _ = try SupatermSettingsCodec.decode(data)
    try fileManager.createDirectory(
      at: settingsURL.deletingLastPathComponent(),
      withIntermediateDirectories: true,
      attributes: nil
    )
    try data.write(to: settingsURL, options: .atomic)
  }
}
