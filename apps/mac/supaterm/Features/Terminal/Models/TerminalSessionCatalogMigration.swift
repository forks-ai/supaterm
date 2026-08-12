import Foundation
import SupatermSupport

nonisolated enum TerminalSessionCatalogMigration {
  enum MigrationError: Error {
    case invalidRoot
    case missingVersion
    case unsupportedVersion(Int)
  }

  static func migrate(_ data: Data) throws -> Data? {
    guard var root = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw MigrationError.invalidRoot
    }
    guard let sourceVersion = (root["version"] as? NSNumber)?.intValue else {
      throw MigrationError.missingVersion
    }
    guard sourceVersion != TerminalSessionCatalog.currentVersion else { return nil }

    var version = sourceVersion
    while version != TerminalSessionCatalog.currentVersion {
      switch version {
      case 10:
        root = migrateVersion10(root)
        version = 11
      default:
        throw MigrationError.unsupportedVersion(version)
      }
    }

    root["version"] = version
    let migrated = try JSONSerialization.data(withJSONObject: root, options: [.sortedKeys])
    _ = try JSONDecoder().decode(TerminalSessionCatalog.self, from: migrated)
    return migrated
  }

  @discardableResult
  static func migrateStoredCatalog(
    at url: URL,
    fileManager: FileManager = .default
  ) -> Bool {
    guard fileManager.fileExists(atPath: url.path(percentEncoded: false)) else { return false }
    do {
      let data = try Data(contentsOf: url)
      guard let migrated = try migrate(data) else { return false }
      try migrated.write(to: url, options: .atomic)
      SupatermLog.notice(
        SupatermLog.terminal,
        "terminal.session.migrated",
        fields: ["version=\(TerminalSessionCatalog.currentVersion)"]
      )
      return true
    } catch {
      SupatermLog.error(
        SupatermLog.terminal,
        "terminal.session.migration.failed",
        fields: ["error=\(String(reflecting: type(of: error)))"]
      )
      return false
    }
  }

  private static func migrateVersion10(_ root: [String: Any]) -> [String: Any] {
    var root = migrateActiveChildren(in: root) as? [String: Any] ?? root
    root["version"] = 11
    return root
  }

  private static func migrateActiveChildren(in value: Any) -> Any {
    if var object = value as? [String: Any] {
      for key in Array(object.keys) {
        guard let nestedValue = object[key] else { continue }
        object[key] = migrateActiveChildren(in: nestedValue)
      }
      if var children = object["activeChildren"] as? [[String: Any]] {
        for index in children.indices where children[index]["kind"] == nil {
          children[index]["kind"] =
            children[index]["role"] as? String == "workflow-subagent"
            ? "workflow"
            : "subagent"
        }
        object["activeChildren"] = children
      }
      return object
    }
    if let values = value as? [Any] {
      return values.map(migrateActiveChildren)
    }
    return value
  }
}
