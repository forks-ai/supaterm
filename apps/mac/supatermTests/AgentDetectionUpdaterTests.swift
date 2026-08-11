import Foundation
import Testing

@testable import SupatermSupport

@MainActor
struct AgentDetectionUpdaterTests {
  @Test
  func fetchesRulesAndActivatesTheValidatedSource() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    let remote = rules(generation: 2, marker: "remote")
    let fetcher = Fetcher(
      plans: [
        FetchPlan(
          response: AgentDetectionHTTPResponse(
            url: fixture.rulesURL,
            statusCode: 200,
            data: remote,
            etag: "\"generation-2\""
          )
        )
      ]
    )
    let updater = fixture.updater(fetcher: fetcher)

    let result = try await updater.update()
    let snapshot = await fixture.repository.snapshot()

    #expect(result == .updated(generation: 2))
    #expect(snapshot.origin == .cache)
    #expect(snapshot.generation == 2)
    let requests = await fetcher.capturedRequests
    #expect(requests.map(\.request.url) == [fixture.rulesURL])
    #expect(
      requests.map(\.maximumBytes)
        == [AgentDetectionRuleSetValidator.maximumDocumentBytes]
    )
    #expect(requests[0].request.value(forHTTPHeaderField: "If-None-Match") == nil)
    #expect(try AgentDetectionRuleCache(url: fixture.cacheURL).load()?.rules == remote)
  }

  @Test
  func revalidatesTheCacheWithItsETagAndAcceptsNotModified() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    let cached = rules(generation: 2)
    try AgentDetectionRuleCache(url: fixture.cacheURL).save(
      AgentDetectionRuleCache.Entry(
        rules: cached,
        etag: "\"generation-2\""
      )
    )
    let repository = try fixture.makeRepository()
    let fetcher = Fetcher(
      plans: [
        FetchPlan(
          response: AgentDetectionHTTPResponse(
            url: fixture.rulesURL,
            statusCode: 304,
            data: Data(),
            etag: "\"generation-2\""
          )
        )
      ]
    )
    let updater = fixture.updater(repository: repository, fetcher: fetcher)

    let result = try await updater.update()
    let snapshot = await repository.snapshot()

    #expect(result == .notModified(generation: 2))
    #expect(snapshot.origin == .cache)
    let requests = await fetcher.capturedRequests
    #expect(requests.count == 1)
    #expect(
      requests[0].request.value(forHTTPHeaderField: "If-None-Match")
        == "\"generation-2\""
    )
  }

  @Test
  func coalescesConcurrentUpdates() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    let remote = rules(generation: 2)
    let gate = Gate()
    let fetcher = Fetcher(
      plans: [
        FetchPlan(
          response: AgentDetectionHTTPResponse(
            url: fixture.rulesURL,
            statusCode: 200,
            data: remote,
            etag: "\"generation-2\""
          ),
          gate: gate
        )
      ]
    )
    let updater = fixture.updater(fetcher: fetcher)
    let first = Task { try await updater.update() }
    await waitForRequestCount(1, fetcher: fetcher)
    let second = Task { try await updater.update() }
    await Task.yield()
    await gate.open()

    #expect(try await first.value == .updated(generation: 2))
    #expect(try await second.value == .updated(generation: 2))
    #expect(await fetcher.capturedRequests.count == 1)
  }

  @Test
  func cancelingTheFlightCreatorPreventsCacheActivation() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    let remote = rules(generation: 2)
    let gate = Gate()
    let fetcher = Fetcher(
      plans: [
        FetchPlan(
          response: AgentDetectionHTTPResponse(
            url: fixture.rulesURL,
            statusCode: 200,
            data: remote,
            etag: "\"generation-2\""
          ),
          gate: gate
        )
      ]
    )
    let updater = fixture.updater(fetcher: fetcher)
    let creator = Task { try await updater.update() }
    await waitForRequestCount(1, fetcher: fetcher)

    creator.cancel()
    await gate.open()

    await #expect(throws: CancellationError.self) {
      try await creator.value
    }
    #expect(await fetcher.capturedRequests.count == 1)
    #expect(await fixture.repository.snapshot().origin == .bundle)
    #expect(!FileManager.default.fileExists(atPath: fixture.cacheURL.path))
  }

  @Test
  func alreadyCanceledFlightCreatorSendsNoRequest() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    let startGate = Gate()
    let fetcher = Fetcher(plans: [])
    let updater = fixture.updater(fetcher: fetcher)
    let creator = Task {
      await startGate.wait()
      return try await updater.update()
    }

    creator.cancel()
    await startGate.open()

    await #expect(throws: CancellationError.self) {
      try await creator.value
    }
    #expect(await fetcher.capturedRequests.isEmpty)
    #expect(await fixture.repository.snapshot().origin == .bundle)
  }

  @Test
  func cancelingAJoinedCallerDoesNotCancelTheSharedFlight() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    let remote = rules(generation: 2)
    let gate = Gate()
    let fetcher = Fetcher(
      plans: [
        FetchPlan(
          response: AgentDetectionHTTPResponse(
            url: fixture.rulesURL,
            statusCode: 200,
            data: remote,
            etag: "\"generation-2\""
          ),
          gate: gate
        )
      ]
    )
    let updater = fixture.updater(fetcher: fetcher)
    let creator = Task { try await updater.update() }
    await waitForRequestCount(1, fetcher: fetcher)
    let joined = Task { try await updater.update() }
    await Task.yield()

    joined.cancel()
    await gate.open()

    #expect(try await creator.value == .updated(generation: 2))
    #expect(try await joined.value == .updated(generation: 2))
    #expect(await fetcher.capturedRequests.count == 1)
    #expect(await fixture.repository.snapshot().origin == .cache)
  }

  @Test
  func keepsTheBundleActiveUntilTheRulesArrive() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    let remote = rules(generation: 2)
    let gate = Gate()
    let fetcher = Fetcher(
      plans: [
        FetchPlan(
          response: AgentDetectionHTTPResponse(
            url: fixture.rulesURL,
            statusCode: 200,
            data: remote,
            etag: "\"generation-2\""
          ),
          gate: gate
        )
      ]
    )
    let updater = fixture.updater(fetcher: fetcher)
    let update = Task { try await updater.update() }
    await waitForRequestCount(1, fetcher: fetcher)

    #expect(await fixture.repository.snapshot().origin == .bundle)
    #expect(!FileManager.default.fileExists(atPath: fixture.cacheURL.path))

    await gate.open()
    #expect(try await update.value == .updated(generation: 2))
    #expect(await fixture.repository.snapshot().origin == .cache)
  }

  @Test
  func invalidRulesFailClosed() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    let fetcher = Fetcher(
      plans: [
        FetchPlan(
          response: AgentDetectionHTTPResponse(
            url: fixture.rulesURL,
            statusCode: 200,
            data: Data("not toml".utf8),
            etag: "\"invalid\""
          )
        )
      ]
    )
    let updater = fixture.updater(fetcher: fetcher)

    await #expect(throws: (any Error).self) {
      try await updater.update()
    }
    #expect(await fixture.repository.snapshot().generation == 1)
    #expect(!FileManager.default.fileExists(atPath: fixture.cacheURL.path))
  }

  @Test(
    arguments: [
      "http://example.test/agent-detection/v1/rules.toml",
      "https://cdn.example.test/agent-detection/v1/rules.toml",
      "https://example.test:444/agent-detection/v1/rules.toml",
    ]
  )
  func rejectsResponsesFromAnotherOrigin(responseURL: String) async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    let fetcher = Fetcher(
      plans: [
        FetchPlan(
          response: AgentDetectionHTTPResponse(
            url: try #require(URL(string: responseURL)),
            statusCode: 200,
            data: rules(generation: 2),
            etag: "\"generation-2\""
          )
        )
      ]
    )

    await #expect(throws: AgentDetectionRuleUpdaterError.unexpectedResponseOrigin) {
      try await fixture.updater(fetcher: fetcher).update()
    }
    #expect(await fixture.repository.snapshot().origin == .bundle)
    #expect(!FileManager.default.fileExists(atPath: fixture.cacheURL.path))
  }

  @Test
  func rejectsOversizedRulesBeforeInstall() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    let fetcher = Fetcher(
      plans: [
        FetchPlan(
          response: AgentDetectionHTTPResponse(
            url: fixture.rulesURL,
            statusCode: 200,
            data: Data(
              repeating: 0,
              count: AgentDetectionRuleSetValidator.maximumDocumentBytes + 1
            ),
            etag: "\"large\""
          )
        )
      ]
    )
    let updater = fixture.updater(fetcher: fetcher)

    await #expect(
      throws: AgentDetectionRuleUpdaterError.responseTooLarge(
        maximumBytes: AgentDetectionRuleSetValidator.maximumDocumentBytes
      )
    ) {
      try await updater.update()
    }
    #expect(await fetcher.capturedRequests.count == 1)
    #expect(await fixture.repository.snapshot().origin == .bundle)
  }

  @Test
  func rejectsNotModifiedWithoutAValidatedCache() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    let fetcher = Fetcher(
      plans: [
        FetchPlan(
          response: AgentDetectionHTTPResponse(
            url: fixture.rulesURL,
            statusCode: 304,
            data: Data(),
            etag: nil
          )
        )
      ]
    )
    let updater = fixture.updater(fetcher: fetcher)

    await #expect(throws: AgentDetectionRuleUpdaterError.unexpectedNotModified) {
      try await updater.update()
    }
    #expect(await fixture.repository.snapshot().origin == .bundle)
  }

  @Test
  func rejectsMissingETagAndHTTPFailures() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    let remote = rules(generation: 2)
    let missingETag = Fetcher(
      plans: [
        FetchPlan(
          response: AgentDetectionHTTPResponse(
            url: fixture.rulesURL,
            statusCode: 200,
            data: remote,
            etag: nil
          )
        )
      ]
    )

    await #expect(throws: AgentDetectionRuleUpdaterError.missingETag) {
      try await fixture.updater(fetcher: missingETag).update()
    }
    #expect(await missingETag.capturedRequests.count == 1)

    let unavailable = Fetcher(
      plans: [
        FetchPlan(
          response: AgentDetectionHTTPResponse(
            url: fixture.rulesURL,
            statusCode: 503,
            data: Data(),
            etag: nil
          )
        )
      ]
    )
    await #expect(
      throws: AgentDetectionRuleUpdaterError.invalidStatusCode(503)
    ) {
      try await fixture.updater(fetcher: unavailable).update()
    }
    #expect(await unavailable.capturedRequests.count == 1)
    #expect(await fixture.repository.snapshot().origin == .bundle)
  }

  private func waitForRequestCount(_ count: Int, fetcher: Fetcher) async {
    while await fetcher.capturedRequests.count < count {
      await Task.yield()
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
      result = "running"
      priority = 1
      region = { source = "screen" }
      when = { contains = "\(marker)" }
      """.utf8
    )
  }

  private actor Gate {
    private var isOpen = false
    private var waiters: [CheckedContinuation<Void, Never>] = []

    func wait() async {
      guard !isOpen else { return }
      await withCheckedContinuation { continuation in
        waiters.append(continuation)
      }
    }

    func open() {
      isOpen = true
      let waiters = waiters
      self.waiters.removeAll()
      for waiter in waiters {
        waiter.resume()
      }
    }
  }

  private struct FetchPlan: Sendable {
    let response: AgentDetectionHTTPResponse
    let gate: Gate?

    init(response: AgentDetectionHTTPResponse, gate: Gate? = nil) {
      self.response = response
      self.gate = gate
    }
  }

  private struct CapturedRequest: Sendable {
    let request: URLRequest
    let maximumBytes: Int
  }

  private enum FetcherError: Error {
    case exhausted
  }

  private actor Fetcher {
    private var plans: [FetchPlan]
    private(set) var capturedRequests: [CapturedRequest] = []

    init(plans: [FetchPlan]) {
      self.plans = plans
    }

    func fetch(
      request: URLRequest,
      maximumBytes: Int
    ) async throws -> AgentDetectionHTTPResponse {
      capturedRequests.append(
        CapturedRequest(request: request, maximumBytes: maximumBytes)
      )
      guard !plans.isEmpty else { throw FetcherError.exhausted }
      let plan = plans.removeFirst()
      if let gate = plan.gate {
        await gate.wait()
      }
      return plan.response
    }
  }

  private struct Fixture {
    let bundle: Data
    let cacheURL: URL
    let repository: AgentDetectionRuleRepository
    let rulesURL = URL(string: "https://example.test/agent-detection/v1/rules.toml")!

    init(bundleGeneration: UInt64) throws {
      let bundle = AgentDetectionUpdaterTests.rules(generation: bundleGeneration)
      let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("supaterm-agent-updater-\(UUID().uuidString)", isDirectory: true)
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
      let cacheURL = directory.appendingPathComponent("rules.plist")
      self.bundle = bundle
      self.cacheURL = cacheURL
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

    func updater(
      repository: AgentDetectionRuleRepository? = nil,
      fetcher: Fetcher
    ) -> AgentDetectionRuleUpdater {
      AgentDetectionRuleUpdater(
        repository: repository ?? self.repository,
        rulesURL: rulesURL,
        fetch: { request, maximumBytes in
          try await fetcher.fetch(request: request, maximumBytes: maximumBytes)
        }
      )
    }
  }
}
