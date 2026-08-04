import Foundation

public enum SupatermSettingsValueKind: String, Codable, Equatable, Sendable {
  case bool
  case string
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

public struct SupatermSettingsValidateRequest: Codable, Equatable, Sendable {
  public let path: String?

  public init(path: String? = nil) {
    self.path = path
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

public enum SupatermSettingsValidationStatus: String, Codable, Sendable {
  case invalid
  case missing
  case valid
}

public struct SupatermSettingsValidationResult: Codable, Equatable, Sendable {
  public let path: String
  public let status: SupatermSettingsValidationStatus
  public let warnings: [String]
  public let errors: [String]

  public init(
    path: String,
    status: SupatermSettingsValidationStatus,
    warnings: [String],
    errors: [String]
  ) {
    self.path = path
    self.status = status
    self.warnings = warnings
    self.errors = errors
  }

  public var isFailure: Bool {
    !errors.isEmpty || status == .invalid
  }
}
