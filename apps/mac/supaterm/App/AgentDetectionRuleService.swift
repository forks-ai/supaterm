import Foundation
import SupatermSupport

enum AgentDetectionRuleServiceError: Error, Equatable, LocalizedError {
  case unreadableRules
  case invalidRules

  var errorDescription: String? {
    switch self {
    case .unreadableRules:
      "The bundled agent detection rules cannot be read."
    case .invalidRules:
      "The bundled agent detection rules are invalid."
    }
  }
}

@MainActor
final class AgentDetectionRuleService {
  typealias Read = @Sendable (URL) throws -> Data
  typealias Sleep = @Sendable (Duration) async throws -> Void
  typealias Update = @Sendable () async throws -> AgentDetectionRuleUpdateResult

  private enum Lifecycle {
    case ready
    case running(Task<Void, Never>)
    case stopped
  }

  static let rulesURL = URL(string: "https://supaterm.com/agent-detection/v1/rules.toml")!
  static let updateInterval = Duration.seconds(21_600)

  let repository: AgentDetectionRuleRepository

  private let sleep: Sleep
  private let update: Update
  private var lifecycle = Lifecycle.ready

  init(
    resourceDirectoryURL: URL,
    cacheURL: URL,
    rulesURL: URL = AgentDetectionRuleService.rulesURL,
    read: @escaping Read = { try Data(contentsOf: $0) },
    update: Update? = nil,
    sleep: @escaping Sleep = { try await Task.sleep(for: $0) }
  ) throws {
    let bundledRulesURL = Self.rulesURL(in: resourceDirectoryURL)
    let bundledRules: Data
    do {
      bundledRules = try read(bundledRulesURL)
    } catch {
      throw AgentDetectionRuleServiceError.unreadableRules
    }
    let repository: AgentDetectionRuleRepository
    do {
      repository = try AgentDetectionRuleRepository(
        bundledRules: bundledRules,
        cacheURL: cacheURL
      )
    } catch {
      throw AgentDetectionRuleServiceError.invalidRules
    }
    self.repository = repository
    if let update {
      self.update = update
    } else {
      let updater = AgentDetectionRuleUpdater(repository: repository, rulesURL: rulesURL)
      self.update = { try await updater.update() }
    }
    self.sleep = sleep
  }

  deinit {
    if case .running(let task) = lifecycle {
      task.cancel()
    }
  }

  static func rulesURL(in directoryURL: URL) -> URL {
    directoryURL.appending(
      path: "AgentDetection",
      directoryHint: .isDirectory
    )
    .appending(path: "rules.toml", directoryHint: .notDirectory)
  }

  static func cacheURL(in cachesDirectoryURL: URL, bundleIdentifier: String) -> URL {
    cachesDirectoryURL
      .appending(path: bundleIdentifier, directoryHint: .isDirectory)
      .appending(path: "AgentDetection", directoryHint: .isDirectory)
      .appending(path: "rules.plist", directoryHint: .notDirectory)
  }

  func start() {
    guard case .ready = lifecycle else { return }
    let repository = repository
    let sleep = sleep
    let update = update
    let task = Task {
      let snapshot = await repository.snapshot()
      Self.log(snapshot: snapshot)
      while !Task.isCancelled {
        do {
          Self.log(result: try await update())
        } catch {
          guard !Task.isCancelled else { return }
          Self.log(error: error)
        }
        guard !Task.isCancelled else { return }
        do {
          try await sleep(Self.updateInterval)
        } catch {
          return
        }
      }
    }
    lifecycle = .running(task)
  }

  func stop() {
    if case .running(let task) = lifecycle {
      task.cancel()
    }
    lifecycle = .stopped
  }

  private static func log(snapshot: AgentDetectionRuleSnapshot) {
    SupatermLog.notice(
      SupatermLog.terminal,
      "agent_detection.rules.loaded",
      fields: [
        "origin=\(originName(snapshot.origin))",
        "generation=\(snapshot.generation)",
        "result=active",
      ]
    )
  }

  private static func log(result: AgentDetectionRuleUpdateResult) {
    let name: String
    let generation: UInt64
    switch result {
    case .updated(let value):
      name = "updated"
      generation = value
    case .unchanged(let value):
      name = "unchanged"
      generation = value
    case .notModified(let value):
      name = "not_modified"
      generation = value
    }
    SupatermLog.notice(
      SupatermLog.terminal,
      "agent_detection.rules.update",
      fields: [
        "origin=remote",
        "generation=\(generation)",
        "result=\(name)",
      ]
    )
  }

  private static func log(error: any Error) {
    SupatermLog.error(
      SupatermLog.terminal,
      "agent_detection.rules.update",
      fields: [
        "origin=remote",
        "result=failed",
        "error=\(String(reflecting: type(of: error)))",
      ]
    )
  }

  private static func originName(_ origin: AgentDetectionRuleOrigin) -> String {
    switch origin {
    case .bundle:
      "bundle"
    case .cache:
      "cache"
    }
  }
}
