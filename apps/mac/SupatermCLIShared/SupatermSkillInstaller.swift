import Foundation

public struct SupatermSkillInstaller {
  public static let manualInstallCommand = "sp agent install-skill"

  let homeDirectoryURL: URL
  let bundledSkillDirectoryURL: URL?
  let fileManager: FileManager

  public init(
    homeDirectoryURL: URL = FileManager.default.homeDirectoryForCurrentUser,
    bundledSkillDirectoryURL: URL? = Self.bundledSkillDirectoryURL(),
    fileManager: FileManager = .default
  ) {
    self.homeDirectoryURL = homeDirectoryURL
    self.bundledSkillDirectoryURL = bundledSkillDirectoryURL
    self.fileManager = fileManager
  }

  public func hasSupatermSkillInstalled() -> Bool {
    if symbolicLinkDestination(at: Self.skillDirectoryURL(homeDirectoryURL: homeDirectoryURL)) != nil {
      return true
    }
    return fileManager.fileExists(atPath: Self.skillDefinitionURL(homeDirectoryURL: homeDirectoryURL).path)
  }

  public func installSupatermSkill() throws {
    guard let bundledSkillDirectoryURL,
      fileManager.fileExists(
        atPath: Self.skillDefinitionURL(skillDirectoryURL: bundledSkillDirectoryURL).path
      )
    else {
      throw SupatermSkillInstallerError.bundledSkillUnavailable(bundledSkillDirectoryURL?.path)
    }

    let skillDirectoryURL = Self.skillDirectoryURL(homeDirectoryURL: homeDirectoryURL)
    try fileManager.createDirectory(
      at: skillDirectoryURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    if symbolicLinkDestination(at: skillDirectoryURL) != nil || fileManager.fileExists(atPath: skillDirectoryURL.path) {
      try fileManager.removeItem(at: skillDirectoryURL)
    }
    try fileManager.createSymbolicLink(at: skillDirectoryURL, withDestinationURL: bundledSkillDirectoryURL)
  }

  public static func skillsDirectoryURL(homeDirectoryURL: URL) -> URL {
    homeDirectoryURL
      .appendingPathComponent(".agents", isDirectory: true)
      .appendingPathComponent("skills", isDirectory: true)
  }

  public static func skillDirectoryURL(homeDirectoryURL: URL) -> URL {
    skillsDirectoryURL(homeDirectoryURL: homeDirectoryURL)
      .appendingPathComponent("supaterm", isDirectory: true)
  }

  public static func skillDefinitionURL(homeDirectoryURL: URL) -> URL {
    skillDefinitionURL(skillDirectoryURL: skillDirectoryURL(homeDirectoryURL: homeDirectoryURL))
  }

  public static func skillDefinitionURL(skillDirectoryURL: URL) -> URL {
    skillDirectoryURL
      .appendingPathComponent("SKILL.md", isDirectory: false)
  }

  public static func bundledSkillDirectoryURL(
    resourceURL: URL? = Bundle.main.resourceURL,
    executableURL: URL? = Bundle.main.executableURL,
    fileManager: FileManager = .default
  ) -> URL? {
    var candidates = [
      resourceURL?
        .appendingPathComponent("skills", isDirectory: true)
        .appendingPathComponent("supaterm", isDirectory: true),
    ].compactMap { $0 }
    if let executableURL {
      candidates.append(skillDirectoryURL(nextToExecutableURL: executableURL))
      let resolvedExecutableURL = executableURL.resolvingSymlinksInPath()
      if resolvedExecutableURL != executableURL {
        candidates.append(skillDirectoryURL(nextToExecutableURL: resolvedExecutableURL))
      }
    }
    return candidates.first {
      fileManager.fileExists(atPath: skillDefinitionURL(skillDirectoryURL: $0).path)
    } ?? candidates.first
  }

  private static func skillDirectoryURL(nextToExecutableURL executableURL: URL) -> URL {
    executableURL
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("skills", isDirectory: true)
      .appendingPathComponent("supaterm", isDirectory: true)
  }

  private func symbolicLinkDestination(at url: URL) -> String? {
    try? fileManager.destinationOfSymbolicLink(atPath: url.path)
  }
}

public enum SupatermSkillInstallerError: Error, Equatable, LocalizedError {
  case bundledSkillUnavailable(String?)

  public var errorDescription: String? {
    switch self {
    case .bundledSkillUnavailable(let path):
      guard let path else {
        return "Supaterm bundled skill is missing."
      }
      return "Supaterm bundled skill is missing at \(path)."
    }
  }
}
