import Foundation
import Testing

@testable import SupatermSupport

@MainActor
struct AgentDetectionRuleSourceTests {
  @Test
  func usesBundledRulesWithoutANetworkCache() async throws {
    let fixture = try RepositoryFixture(bundle: rules(generation: 1, marker: "bundle"))
    let snapshot = await fixture.repository.snapshot()

    #expect(snapshot.origin == .bundle)
    #expect(snapshot.generation == 1)
    #expect(snapshot.processManifests.map(\.agentID) == ["agent"])
    #expect(
      await fixture.repository.evaluate(
        agentID: "agent",
        input: AgentDetectionInput(screen: "bundle", rawTitle: "")
      )?.match == .matched(result: .idle, ruleID: "state", priority: 1)
    )
  }

  @Test
  func usesValidCachedRulesNewerThanTheBundle() async throws {
    let bundle = rules(generation: 1, marker: "bundle")
    let cached = rules(generation: 2, marker: "cached")
    let fixture = try RepositoryFixture(bundle: bundle)
    try fixture.cache.save(
      AgentDetectionRuleCache.Entry(
        rules: cached,
        etag: "\"generation-2\""
      )
    )

    let repository = try fixture.makeRepository()
    let snapshot = await repository.snapshot()

    #expect(snapshot.origin == .cache)
    #expect(snapshot.generation == 2)
    #expect(
      await repository.evaluate(
        agentID: "agent",
        input: AgentDetectionInput(screen: "cached", rawTitle: "")
      )?.match != .noMatch
    )
  }

  @Test
  func ignoresMalformedCachedRules() async throws {
    let fixture = try RepositoryFixture(bundle: rules(generation: 1))
    try fixture.cache.save(
      AgentDetectionRuleCache.Entry(
        rules: Data("not toml".utf8),
        etag: "\"invalid\""
      )
    )

    let repository = try fixture.makeRepository()
    let snapshot = await repository.snapshot()
    let cachedEntry = await repository.cachedEntryForRevalidation

    #expect(snapshot.origin == .bundle)
    #expect(snapshot.generation == 1)
    #expect(cachedEntry == nil)
  }

  @Test
  func newerBundledRulesBeatAStaleCache() async throws {
    let fixture = try RepositoryFixture(bundle: rules(generation: 3, marker: "bundle"))
    let cached = rules(generation: 2, marker: "cached")
    try fixture.cache.save(
      AgentDetectionRuleCache.Entry(
        rules: cached,
        etag: "\"generation-2\""
      )
    )

    let repository = try fixture.makeRepository()
    let snapshot = await repository.snapshot()

    #expect(snapshot.origin == .bundle)
    #expect(snapshot.generation == 3)
  }

  @Test
  func rejectsCachedRulesWithConflictingBytesAtTheBundledGeneration() async throws {
    let fixture = try RepositoryFixture(bundle: rules(generation: 2, marker: "bundle"))
    let cached = rules(generation: 2, marker: "cached")
    try fixture.cache.save(
      AgentDetectionRuleCache.Entry(
        rules: cached,
        etag: "\"generation-2\""
      )
    )

    let repository = try fixture.makeRepository()
    let snapshot = await repository.snapshot()
    let cachedEntry = await repository.cachedEntryForRevalidation

    #expect(snapshot.origin == .bundle)
    #expect(snapshot.generation == 2)
    #expect(cachedEntry == nil)
    #expect(
      await repository.evaluate(
        agentID: "agent",
        input: AgentDetectionInput(screen: "bundle", rawTitle: "")
      )?.match == .matched(result: .idle, ruleID: "state", priority: 1)
    )
  }

  @Test
  func rejectsDifferentBytesAtTheBundledGeneration() async throws {
    let fixture = try RepositoryFixture(bundle: rules(generation: 2, marker: "bundle"))
    let remote = rules(generation: 2, marker: "remote")

    await #expect(
      throws: AgentDetectionRuleRepositoryError.conflictingGeneration(2)
    ) {
      try await fixture.repository.install(
        rules: remote,
        etag: "\"remote\""
      )
    }
    let snapshot = await fixture.repository.snapshot()
    #expect(snapshot.origin == .bundle)
    #expect(
      await fixture.repository.evaluate(
        agentID: "agent",
        input: AgentDetectionInput(screen: "bundle", rawTitle: "")
      )?.match == .matched(result: .idle, ruleID: "state", priority: 1)
    )
    #expect(!FileManager.default.fileExists(atPath: fixture.cacheURL.path))
  }

  @Test
  func rejectsAStaleRemoteWithoutReplacingTheCache() async throws {
    let fixture = try RepositoryFixture(bundle: rules(generation: 3))
    let stale = rules(generation: 2)

    await #expect(
      throws: AgentDetectionRuleRepositoryError.staleGeneration(candidate: 2, current: 3)
    ) {
      try await fixture.repository.install(
        rules: stale,
        etag: "\"stale\""
      )
    }
    #expect(await fixture.repository.snapshot().generation == 3)
    #expect(!FileManager.default.fileExists(atPath: fixture.cacheURL.path))
  }

  @Test
  func validatesEveryAgentBeforeReplacingTheActiveSource() async throws {
    let fixture = try RepositoryFixture(bundle: rules(generation: 1))
    let invalid =
      rules(generation: 2)
      + Data(
        """

        [[agents]]
        id = "broken"
        display_name = "Broken"
        processes = [{ executable = "broken" }]

        [[agents.rules]]
        id = "broken"
        result = "running"
        priority = 1
        region = { source = "screen" }
        when = { regex = "[" }
        """.utf8
      )

    await #expect(throws: (any Error).self) {
      try await fixture.repository.install(
        rules: invalid,
        etag: "\"invalid-rules\""
      )
    }
    #expect(await fixture.repository.snapshot().generation == 1)
    #expect(!FileManager.default.fileExists(atPath: fixture.cacheURL.path))
  }

  @Test
  func evaluationTagsTheSourceInstalledAfterAnOlderSnapshot() async throws {
    let fixture = try RepositoryFixture(bundle: rules(generation: 1, marker: "bundle"))
    let oldSnapshot = await fixture.repository.snapshot()
    let remoteRules = try #require(
      String(bytes: rules(generation: 2, marker: "remote"), encoding: .utf8)
    )
    let remote = Data(
      remoteRules.replacingOccurrences(
        of: "display_name = \"Agent\"",
        with: "display_name = \"Updated Agent\""
      ).utf8
    )

    _ = try await fixture.repository.install(
      rules: remote,
      etag: "\"generation-2\""
    )
    let evaluation = try #require(
      await fixture.repository.evaluate(
        agentID: "agent",
        input: AgentDetectionInput(screen: "remote", rawTitle: "")
      )
    )

    #expect(oldSnapshot.generation == 1)
    #expect(evaluation.generation == 2)
    #expect(
      evaluation.identity
        == AgentDetectionAgentIdentity(id: "agent", displayName: "Updated Agent")
    )
    #expect(evaluation.match == .matched(result: .idle, ruleID: "state", priority: 1))
  }

  @Test
  func storesOneAtomicPropertyListWithTheRawResponse() throws {
    let fixture = try RepositoryFixture(bundle: rules(generation: 1))
    let rawRules = rules(generation: 2)
    let entry = AgentDetectionRuleCache.Entry(
      rules: rawRules,
      etag: "\"generation-2\""
    )

    try fixture.cache.save(entry)

    #expect(try fixture.cache.load() == entry)
    let value = try #require(
      PropertyListSerialization.propertyList(
        from: Data(contentsOf: fixture.cacheURL),
        format: nil
      ) as? [String: Any]
    )
    #expect(value["rules"] as? Data == rawRules)
    #expect(value["etag"] as? String == "\"generation-2\"")
    let files = try FileManager.default.contentsOfDirectory(
      at: fixture.directory,
      includingPropertiesForKeys: nil
    )
    #expect(files.count == 1)
    #expect(files.first?.lastPathComponent == fixture.cacheURL.lastPathComponent)
  }

  @Test
  func enforcesCacheAndRuleSizeCaps() throws {
    let fixture = try RepositoryFixture(bundle: rules(generation: 1))
    try Data(
      repeating: 0,
      count: AgentDetectionRuleCache.maximumFileBytes + 1
    ).write(to: fixture.cacheURL)

    #expect(throws: AgentDetectionRuleCacheError.fileTooLarge) {
      try fixture.cache.load()
    }
    #expect(throws: AgentDetectionRuleCacheError.rulesTooLarge) {
      try fixture.cache.save(
        AgentDetectionRuleCache.Entry(
          rules: Data(
            repeating: 0,
            count: AgentDetectionRuleSetValidator.maximumDocumentBytes + 1
          ),
          etag: "\"large\""
        )
      )
    }
  }

  private func rules(generation: UInt64, marker: String = "ready") -> Data {
    Self.rules(generation: generation, marker: marker)
  }

  private static func rules(generation: UInt64, marker: String = "ready") -> Data {
    Data(
      """
      format_version = 1
      generation = \(generation)
      minimum_engine_version = 1

      [[agents]]
      id = "agent"
      display_name = "Agent"
      processes = [{ executable = "agent" }]

      [[agents.rules]]
      id = "state"
      result = "idle"
      priority = 1
      region = { source = "screen" }
      when = { contains = "\(marker)" }
      """.utf8
    )
  }

  private struct RepositoryFixture {
    let bundle: Data
    let cacheURL: URL
    let directory: URL
    let repository: AgentDetectionRuleRepository

    var cache: AgentDetectionRuleCache {
      AgentDetectionRuleCache(url: cacheURL)
    }

    init(bundle: Data) throws {
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("supaterm-agent-rules-\(UUID().uuidString)", isDirectory: true)
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      let cacheURL = directory.appendingPathComponent("rules.plist")
      self.bundle = bundle
      self.cacheURL = cacheURL
      self.directory = directory
      repository = try AgentDetectionRuleRepository(
        bundledRules: bundle,
        cacheURL: cacheURL
      )
    }

    func makeRepository() throws -> AgentDetectionRuleRepository {
      try AgentDetectionRuleRepository(
        bundledRules: bundle,
        cacheURL: cacheURL
      )
    }
  }
}
