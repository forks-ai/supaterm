import Foundation

public enum AgentDetectionRuleOrigin: Equatable, Sendable {
  case bundle
  case cache
}

public struct AgentDetectionAgentIdentity: Equatable, Hashable, Sendable {
  public let id: String
  public let displayName: String

  public init(id: String, displayName: String) {
    self.id = id
    self.displayName = displayName
  }
}

public struct AgentDetectionRuleSnapshot: Equatable, Sendable {
  public let origin: AgentDetectionRuleOrigin
  public let generation: UInt64
  public let processManifests: [AgentDetectionProcessManifest]

  public init(
    origin: AgentDetectionRuleOrigin,
    generation: UInt64,
    processManifests: [AgentDetectionProcessManifest]
  ) {
    self.origin = origin
    self.generation = generation
    self.processManifests = processManifests
  }
}

public struct AgentDetectionEvaluation: Equatable, Sendable {
  public let identity: AgentDetectionAgentIdentity
  public let generation: UInt64
  public let match: AgentDetectionMatch

  public init(
    identity: AgentDetectionAgentIdentity,
    generation: UInt64,
    match: AgentDetectionMatch
  ) {
    self.identity = identity
    self.generation = generation
    self.match = match
  }
}

enum AgentDetectionRuleRepositoryError: Error, Equatable, LocalizedError, Sendable {
  case staleGeneration(candidate: UInt64, current: UInt64)
  case conflictingGeneration(UInt64)

  var errorDescription: String? {
    switch self {
    case .staleGeneration(let candidate, let current):
      "Agent detection rule generation \(candidate) is older than active generation \(current)."
    case .conflictingGeneration(let generation):
      "Agent detection rule generation \(generation) has conflicting bytes."
    }
  }
}

enum AgentDetectionRuleInstallResult: Equatable, Sendable {
  case updated(generation: UInt64)
  case unchanged(generation: UInt64)
}

public actor AgentDetectionRuleRepository {
  private struct Source {
    let origin: AgentDetectionRuleOrigin
    let rawRules: Data
    let ruleSet: AgentDetectionRuleSet
    let matchers: [AgentDetectionMatcher]

    init(rules: Data, origin: AgentDetectionRuleOrigin) throws {
      let ruleSet = try AgentDetectionRuleSetParser.parse(rules)
      let matchers = try ruleSet.agents.map { try AgentDetectionMatcher(agent: $0) }
      self.origin = origin
      rawRules = rules
      self.ruleSet = ruleSet
      self.matchers = matchers
    }
  }

  private let cache: AgentDetectionRuleCache
  private var source: Source
  private(set) var cachedEntryForRevalidation: AgentDetectionRuleCache.Entry?

  var generation: UInt64 {
    source.ruleSet.generation
  }

  public init(
    bundledRules: Data,
    cacheURL: URL
  ) throws {
    let bundle = try Source(rules: bundledRules, origin: .bundle)
    let cache = AgentDetectionRuleCache(url: cacheURL)
    var source = bundle
    var cachedEntryForRevalidation: AgentDetectionRuleCache.Entry?

    if let entry = try? cache.load(),
      let cached = try? Source(rules: entry.rules, origin: .cache),
      cached.ruleSet.generation != bundle.ruleSet.generation
        || cached.rawRules == bundle.rawRules
    {
      cachedEntryForRevalidation = entry
      if cached.ruleSet.generation > bundle.ruleSet.generation {
        source = cached
      }
    }

    self.cache = cache
    self.source = source
    self.cachedEntryForRevalidation = cachedEntryForRevalidation
  }

  public func snapshot() -> AgentDetectionRuleSnapshot {
    AgentDetectionRuleSnapshot(
      origin: source.origin,
      generation: source.ruleSet.generation,
      processManifests: source.ruleSet.agents.map {
        AgentDetectionProcessManifest(agentID: $0.id, processes: $0.processes)
      }
    )
  }

  public func evaluate(
    agentID: String,
    input: AgentDetectionInput
  ) -> AgentDetectionEvaluation? {
    guard let index = source.ruleSet.agents.firstIndex(where: { $0.id == agentID }) else {
      return nil
    }
    let agent = source.ruleSet.agents[index]
    return AgentDetectionEvaluation(
      identity: AgentDetectionAgentIdentity(id: agent.id, displayName: agent.displayName),
      generation: source.ruleSet.generation,
      match: source.matchers[index].match(input)
    )
  }

  func install(
    rules: Data,
    etag: String
  ) throws -> AgentDetectionRuleInstallResult {
    let candidate = try Source(rules: rules, origin: .cache)
    let generation = candidate.ruleSet.generation
    guard generation >= source.ruleSet.generation else {
      throw AgentDetectionRuleRepositoryError.staleGeneration(
        candidate: generation,
        current: source.ruleSet.generation
      )
    }
    let advancesGeneration = generation > source.ruleSet.generation
    if !advancesGeneration {
      guard candidate.rawRules == source.rawRules else {
        throw AgentDetectionRuleRepositoryError.conflictingGeneration(generation)
      }
    }

    let entry = AgentDetectionRuleCache.Entry(rules: rules, etag: etag)
    try cache.save(entry)
    cachedEntryForRevalidation = entry
    if advancesGeneration {
      source = candidate
      return .updated(generation: generation)
    }
    return .unchanged(generation: generation)
  }
}
