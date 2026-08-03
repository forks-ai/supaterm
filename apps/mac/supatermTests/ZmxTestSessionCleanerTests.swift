import Foundation
import SupatermCLIShared
import SupatermSupport
import Synchronization
import Testing

struct ZmxTestSessionCleanerTests {
  @Test
  func cleanupKillsOnlySessionsForItsInstance() throws {
    let instanceName = "ui-cleanup"
    let instancePrefix = ZmxSessionID.namespacePrefix(
      environment: [SupatermCLIEnvironment.instanceNameKey: instanceName]
    )
    let ownSessionIDs = ["\(instancePrefix)first", "\(instancePrefix)second"]
    let otherSessionID = "spt-other-third"
    let calls = Mutex([[String]]())
    let cleaner = ZmxTestSessionCleaner(instanceName: instanceName) { arguments, environment in
      let callCount = calls.withLock { calls in
        calls.append(arguments)
        return calls.count
      }
      #expect(environment[ZmxEnvironment.directoryKey] == ZmxSocketBudget.socketDir())
      #expect(environment[ZmxEnvironment.sessionKey]?.isEmpty == true)
      #expect(environment[ZmxEnvironment.sessionPrefixKey]?.isEmpty == true)
      if arguments == ["ls", "--short"], callCount == 1 {
        return (ownSessionIDs + [otherSessionID]).joined(separator: "\n")
      }
      if arguments == ["kill"] + ownSessionIDs {
        return ""
      }
      if arguments == ["ls", "--short"] {
        return otherSessionID
      }
      Issue.record("Unexpected arguments: \(arguments)")
      return ""
    }

    try cleaner.cleanup()

    #expect(
      calls.withLock { $0 } == [
        ["ls", "--short"],
        ["kill"] + ownSessionIDs,
        ["ls", "--short"],
      ]
    )
  }

  @Test
  func cleanupFailsWhenItsSessionsRemain() {
    let instanceName = "ui-stuck"
    let instancePrefix = ZmxSessionID.namespacePrefix(
      environment: [SupatermCLIEnvironment.instanceNameKey: instanceName]
    )
    let sessionID = "\(instancePrefix)session"
    let cleaner = ZmxTestSessionCleaner(instanceName: instanceName) { arguments, _ in
      arguments.first == "ls" ? sessionID : ""
    }

    #expect(throws: ZmxTestCleanupError.self) {
      try cleaner.cleanup()
    }
  }

  @Test
  func reapAbandonedCleansOnlyWorkspacesWithoutLiveOwners() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let deadStateHome = temporaryDirectory.appendingPathComponent("supaterm-ui-dead", isDirectory: true)
    let liveStateHome = temporaryDirectory.appendingPathComponent("supaterm-ui-live", isDirectory: true)
    try FileManager.default.createDirectory(at: deadStateHome, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: liveStateHome, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    try "10".write(
      to: deadStateHome.appendingPathComponent(ZmxTestWorkspace.ownerFilename),
      atomically: true,
      encoding: .utf8
    )
    try "20".write(
      to: liveStateHome.appendingPathComponent(ZmxTestWorkspace.ownerFilename),
      atomically: true,
      encoding: .utf8
    )
    let cleanedInstances = Mutex([String]())

    try ZmxTestWorkspace.reapAbandoned(
      in: temporaryDirectory,
      stateHomePrefix: "supaterm-ui-",
      instanceNamePrefix: "ui-",
      processIsRunning: { $0 == 20 },
      cleanupInstance: { instanceName in
        cleanedInstances.withLock { $0.append(instanceName) }
      }
    )

    #expect(cleanedInstances.withLock { $0 } == ["ui-dead"])
    #expect(!FileManager.default.fileExists(atPath: deadStateHome.path))
    #expect(FileManager.default.fileExists(atPath: liveStateHome.path))
  }

  @Test
  func workspaceCleanupKillsBundledZmxSessionAndRemovesState() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let instanceName = "unit-live-\(UUID().uuidString)"
    let sessionID = ZmxSessionID.make(
      surfaceID: UUID(),
      environment: [SupatermCLIEnvironment.instanceNameKey: instanceName]
    )
    let stateHome = temporaryDirectory.appendingPathComponent("direct", isDirectory: true)
    let workspace = try ZmxTestWorkspace(
      stateHome: stateHome,
      instanceName: instanceName,
      zmxExecutableURL: zmxExecutableURL
    )
    let cleaner = ZmxTestSessionCleaner(executableURL: zmxExecutableURL, instanceName: instanceName)
    defer { try? cleaner.cleanup() }
    _ = try ZmxTestSessionCleaner.run(
      executableURL: zmxExecutableURL,
      arguments: ["run", sessionID, "-d", "/bin/sleep", "60"],
      environment: ZmxTestSessionCleaner.environment
    )
    let sessions = try ZmxTestSessionCleaner.run(
      executableURL: zmxExecutableURL,
      arguments: ["ls", "--short"],
      environment: ZmxTestSessionCleaner.environment
    )
    #expect(sessions.split(whereSeparator: \.isNewline).contains(Substring(sessionID)))

    try workspace.cleanup()
    #expect(!FileManager.default.fileExists(atPath: stateHome.path))

    let abandonedStateHome = temporaryDirectory.appendingPathComponent(
      "supaterm-ui-abandoned",
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: abandonedStateHome, withIntermediateDirectories: true)
    try String(Int32.max).write(
      to: abandonedStateHome.appendingPathComponent(ZmxTestWorkspace.ownerFilename),
      atomically: true,
      encoding: .utf8
    )
    try ZmxTestWorkspace.reapAbandoned(
      in: temporaryDirectory,
      stateHomePrefix: "supaterm-ui-",
      instanceNamePrefix: "ui-",
      zmxExecutableURL: zmxExecutableURL
    )
    #expect(!FileManager.default.fileExists(atPath: abandonedStateHome.path))
  }

  private var zmxExecutableURL: URL {
    Bundle(for: ZmxTestBundleToken.self).bundleURL
      .deletingLastPathComponent()
      .appendingPathComponent("supaterm.app/Contents/Helpers/zmx")
  }
}

private final class ZmxTestBundleToken {}
