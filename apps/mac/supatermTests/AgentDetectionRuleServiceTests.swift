import Foundation
import Synchronization
import Testing

@testable import SupatermSupport
@testable import supaterm

@MainActor
struct AgentDetectionRuleServiceTests {
  @Test
  func loadsExactBundlePathsAndCreatesAnOfflineRepository() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    defer { fixture.remove() }
    let agentDetectionDirectoryURL = fixture.resourceDirectoryURL.appending(
      path: "AgentDetection",
      directoryHint: .isDirectory
    )
    let expectedRulesURL = agentDetectionDirectoryURL.appending(path: "rules.toml")
    let reads = Mutex<[URL]>([])
    let updates = Mutex(0)
    let resources = [
      expectedRulesURL: fixture.rules(generation: 1)
    ]

    let service = try AgentDetectionRuleService(
      resourceDirectoryURL: fixture.resourceDirectoryURL,
      cacheURL: fixture.cacheURL,
      read: { url in
        reads.withLock { $0.append(url) }
        guard let data = resources[url] else { throw TestError.failed }
        return data
      },
      update: {
        updates.withLock { $0 += 1 }
        return .notModified(generation: 1)
      }
    )
    let snapshot = await service.repository.snapshot()

    #expect(reads.withLock { $0 } == [expectedRulesURL])
    #expect(updates.withLock { $0 } == 0)
    #expect(snapshot.origin == .bundle)
    #expect(snapshot.generation == 1)
  }

  @Test
  func cachePathIsStableAndAppSpecific() {
    let cachesDirectoryURL = URL(filePath: "/tmp/cache", directoryHint: .isDirectory)

    let cacheURL = AgentDetectionRuleService.cacheURL(
      in: cachesDirectoryURL,
      bundleIdentifier: "app.supabit.supaterm"
    )

    #expect(cacheURL.path == "/tmp/cache/app.supabit.supaterm/AgentDetection/rules.plist")
  }

  @Test
  func missingResourcesDisableBootstrapWithoutAProcessFailure() throws {
    let directory = FileManager.default.temporaryDirectory.appending(
      path: "supaterm-agent-service-missing-\(UUID().uuidString)",
      directoryHint: .isDirectory
    )
    defer { try? FileManager.default.removeItem(at: directory) }

    #expect(throws: AgentDetectionRuleServiceError.unreadableRules) {
      try AgentDetectionRuleService(
        resourceDirectoryURL: directory,
        cacheURL: directory.appending(path: "cache.plist")
      )
    }
  }

  @Test
  func corruptRulesDisableBootstrap() throws {
    let invalidRules = try Fixture(bundleGeneration: 1)
    defer { invalidRules.remove() }
    try Data("invalid".utf8).write(to: invalidRules.rulesURL, options: .atomic)

    #expect(throws: AgentDetectionRuleServiceError.invalidRules) {
      try invalidRules.service()
    }
  }

  @Test
  func startsImmediatelyThenWaitsSixHoursBetweenFailuresAndSuccesses() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    defer { fixture.remove() }
    let updates = Mutex(0)
    let sleeps = Mutex<[Duration]>([])
    let service = try fixture.service(
      update: {
        let count = updates.withLock { value in
          value += 1
          return value
        }
        if count == 1 { throw TestError.failed }
        return .notModified(generation: 1)
      },
      sleep: { duration in
        let count = sleeps.withLock { values in
          values.append(duration)
          return values.count
        }
        if count == 2 { throw CancellationError() }
      }
    )

    service.start()

    #expect(await waitUntil { updates.withLock { $0 } == 2 })
    #expect(
      sleeps.withLock { $0 }
        == [AgentDetectionRuleService.updateInterval, AgentDetectionRuleService.updateInterval]
    )
    #expect(AgentDetectionRuleService.updateInterval == .seconds(21_600))
  }

  @Test
  func duplicateStartDoesNotCreateAnotherUpdateLoop() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    defer { fixture.remove() }
    let updates = Mutex(0)
    let sleepStarted = Mutex(false)
    let service = try fixture.service(
      update: {
        updates.withLock { $0 += 1 }
        return .notModified(generation: 1)
      },
      sleep: { _ in
        sleepStarted.withLock { $0 = true }
        try await Task.sleep(for: .seconds(60))
      }
    )

    service.start()
    service.start()

    #expect(await waitUntil { sleepStarted.withLock { $0 } })
    #expect(updates.withLock { $0 } == 1)
    service.stop()
  }

  @Test
  func stopCancelsTheUpdateLoopAndPreventsRestart() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    defer { fixture.remove() }
    let updates = Mutex(0)
    let sleepStarted = Mutex(false)
    let cancelled = Mutex(false)
    let service = try fixture.service(
      update: {
        updates.withLock { $0 += 1 }
        return .notModified(generation: 1)
      },
      sleep: { _ in
        sleepStarted.withLock { $0 = true }
        try await withTaskCancellationHandler {
          try await Task.sleep(for: .seconds(60))
        } onCancel: {
          cancelled.withLock { $0 = true }
        }
      }
    )

    service.start()
    #expect(await waitUntil { sleepStarted.withLock { $0 } })
    service.stop()

    #expect(await waitUntil { cancelled.withLock { $0 } })
    service.start()
    for _ in 0..<10 {
      await Task.yield()
    }
    #expect(updates.withLock { $0 } == 1)
  }

  @Test
  func deinitCancelsTheUpdateLoop() async throws {
    let fixture = try Fixture(bundleGeneration: 1)
    defer { fixture.remove() }
    let sleepStarted = Mutex(false)
    let cancelled = Mutex(false)
    var service: AgentDetectionRuleService? = try fixture.service(
      update: { .notModified(generation: 1) },
      sleep: { _ in
        sleepStarted.withLock { $0 = true }
        try await withTaskCancellationHandler {
          try await Task.sleep(for: .seconds(60))
        } onCancel: {
          cancelled.withLock { $0 = true }
        }
      }
    )

    service?.start()
    #expect(await waitUntil { sleepStarted.withLock { $0 } })
    service = nil

    #expect(await waitUntil { cancelled.withLock { $0 } })
  }

  private enum TestError: Error {
    case failed
  }

  private struct Fixture {
    let cacheURL: URL
    let directoryURL: URL
    let resourceDirectoryURL: URL
    let rulesURL: URL

    init(bundleGeneration: UInt64) throws {
      let directoryURL = FileManager.default.temporaryDirectory.appending(
        path: "supaterm-agent-service-\(UUID().uuidString)",
        directoryHint: .isDirectory
      )
      let resourceDirectoryURL = directoryURL.appending(
        path: "Resources",
        directoryHint: .isDirectory
      )
      let rulesURL = AgentDetectionRuleService.rulesURL(in: resourceDirectoryURL)
      try FileManager.default.createDirectory(
        at: rulesURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      self.cacheURL = directoryURL.appending(path: "Cache/rules.plist")
      self.directoryURL = directoryURL
      self.resourceDirectoryURL = resourceDirectoryURL
      self.rulesURL = rulesURL
      try rules(generation: bundleGeneration).write(to: rulesURL, options: .atomic)
    }

    func rules(generation: UInt64) -> Data {
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
        id = "idle"
        result = "idle"
        priority = 1
        region = { source = "screen" }
        when = { contains = "ready" }
        """.utf8
      )
    }

    func service(
      update: AgentDetectionRuleService.Update? = nil,
      sleep: @escaping AgentDetectionRuleService.Sleep = { try await Task.sleep(for: $0) }
    ) throws -> AgentDetectionRuleService {
      try AgentDetectionRuleService(
        resourceDirectoryURL: resourceDirectoryURL,
        cacheURL: cacheURL,
        update: update,
        sleep: sleep
      )
    }

    func remove() {
      try? FileManager.default.removeItem(at: directoryURL)
    }
  }
}
