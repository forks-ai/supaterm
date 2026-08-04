import Foundation

public struct SupatermSkillSummary: Codable, Equatable, Sendable {
  public let name: String
  public let description: String

  public init(name: String, description: String) {
    self.name = name
    self.description = description
  }
}

public struct SupatermSkillFile: Codable, Equatable, Sendable {
  public let path: String
  public let content: String

  public init(path: String, content: String) {
    self.path = path
    self.content = content
  }
}

public struct SupatermSkillContent: Codable, Equatable, Sendable {
  public let name: String
  public let content: String
  public let files: [SupatermSkillFile]?

  public init(name: String, content: String, files: [SupatermSkillFile]? = nil) {
    self.name = name
    self.content = content
    self.files = files
  }
}

public struct SupatermSkillInstallResult: Codable, Equatable, Sendable {
  public let path: String

  public init(path: String) {
    self.path = path
  }
}

public struct SupatermSkillListResult: Codable, Equatable, Sendable {
  public let skills: [SupatermSkillSummary]

  public init(skills: [SupatermSkillSummary]) {
    self.skills = skills
  }
}

public struct SupatermSkillGetRequest: Codable, Equatable, Sendable {
  public let name: String
  public let full: Bool

  public init(name: String, full: Bool = false) {
    self.name = name
    self.full = full
  }
}

public struct SupatermSkillPathRequest: Codable, Equatable, Sendable {
  public let name: String

  public init(name: String) {
    self.name = name
  }
}

public struct SupatermSkillPathResult: Codable, Equatable, Sendable {
  public let path: String

  public init(path: String) {
    self.path = path
  }
}
