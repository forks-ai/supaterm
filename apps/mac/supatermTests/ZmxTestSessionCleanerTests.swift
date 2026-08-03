import Foundation
import SupatermCLIShared
import SupatermSupport
import Synchronization
import Testing

struct ZmxTestSessionCleanerTests {
  @Test
  func cleanupKillsOnlySessionsForItsInstance() throws {
    let instanceName = "ui-cleanup"
    let directory = FileManager.default.temporaryDirectory.path
    let instancePrefix = ZmxSessionID.namespacePrefix(
      environment: [SupatermCLIEnvironment.instanceNameKey: instanceName]
    )
    let ownSessionIDs = ["\(instancePrefix)first", "\(instancePrefix)second"]
    let otherSessionID = "spt-other-third"
    let calls = Mutex([[String]]())
    let cleaner = ZmxTestSessionCleaner(instanceName: instanceName, directory: directory) {
      arguments, environment in
      let callCount = calls.withLock { calls in
        calls.append(arguments)
        return calls.count
      }
      #expect(environment[ZmxEnvironment.directoryKey] == directory)
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
    let cleaner = ZmxTestSessionCleaner(
      instanceName: instanceName,
      directory: FileManager.default.temporaryDirectory.path
    ) { arguments, _ in
      arguments.first == "ls" ? sessionID : ""
    }

    #expect(throws: ZmxTestCleanupError.self) {
      try cleaner.cleanup()
    }
  }

  @Test
  func cleanupSkipsMissingDirectory() throws {
    let calls = Mutex([[String]]())
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let cleaner = ZmxTestSessionCleaner(
      instanceName: "ui-missing",
      directory: directory.path
    ) { arguments, _ in
      calls.withLock { $0.append(arguments) }
      return ""
    }

    try cleaner.cleanup()

    #expect(calls.withLock { $0 }.isEmpty)
  }

  @Test
  func reapAbandonedCleansOnlyWorkspacesWithoutLiveOwners() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let deadStateHome = temporaryDirectory.appendingPathComponent("supaterm-ui-dead", isDirectory: true)
    let liveStateHome = temporaryDirectory.appendingPathComponent("supaterm-ui-live", isDirectory: true)
    try FileManager.default.createDirectory(at: deadStateHome, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    try writeOwner(ZmxTestWorkspace.Owner(runnerProcess: deadProcess, appProcess: nil), to: deadStateHome)
    _ = try ZmxTestWorkspace(
      stateHome: liveStateHome,
      instanceName: "ui-live",
      zmxExecutableURL: URL(fileURLWithPath: "/usr/bin/true")
    )
    let cleanedInstances = Mutex([String]())

    try ZmxTestWorkspace.reapAbandoned(
      in: temporaryDirectory,
      stateHomePrefix: "supaterm-ui-",
      instanceNamePrefix: "ui-",
      cleanupInstance: { instanceName in
        cleanedInstances.withLock { $0.append(instanceName) }
      }
    )

    #expect(cleanedInstances.withLock { $0 } == ["ui-dead"])
    #expect(!FileManager.default.fileExists(atPath: deadStateHome.path))
    #expect(FileManager.default.fileExists(atPath: liveStateHome.path))
  }

  @Test
  func reapAbandonedTerminatesRecordedApp() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let stateHome = temporaryDirectory.appendingPathComponent("supaterm-ui-dead", isDirectory: true)
    try FileManager.default.createDirectory(at: stateHome, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let process = try launchSleepProcess()
    defer { stop(process) }
    let workspace = try ZmxTestWorkspace(
      stateHome: stateHome,
      instanceName: "ui-dead",
      zmxExecutableURL: URL(fileURLWithPath: "/usr/bin/true")
    )
    try workspace.recordApp(process)
    let owner = try readOwner(from: stateHome)
    try writeOwner(
      ZmxTestWorkspace.Owner(runnerProcess: deadProcess, appProcess: owner.appProcess),
      to: stateHome
    )

    try ZmxTestWorkspace.reapAbandoned(
      in: temporaryDirectory,
      stateHomePrefix: "supaterm-ui-",
      instanceNamePrefix: "ui-",
      cleanupInstance: { _ in }
    )

    #expect(!process.isRunning)
  }

  @Test
  func reapAbandonedDoesNotSignalAReusedProcessID() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let stateHome = temporaryDirectory.appendingPathComponent("supaterm-ui-dead", isDirectory: true)
    try FileManager.default.createDirectory(at: stateHome, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let process = try launchSleepProcess()
    defer { stop(process) }
    let appProcess = ZmxTestWorkspace.ProcessIdentity(
      processID: process.processIdentifier,
      startTimeSeconds: .max,
      startTimeMicroseconds: .max
    )
    try writeOwner(
      ZmxTestWorkspace.Owner(runnerProcess: deadProcess, appProcess: appProcess),
      to: stateHome
    )

    try ZmxTestWorkspace.reapAbandoned(
      in: temporaryDirectory,
      stateHomePrefix: "supaterm-ui-",
      instanceNamePrefix: "ui-",
      cleanupInstance: { _ in }
    )

    #expect(process.isRunning)
  }

  @Test
  func abandonedWorkspaceCanBeClaimedOnce() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let stateHome = temporaryDirectory.appendingPathComponent("supaterm-ui-dead", isDirectory: true)
    try FileManager.default.createDirectory(at: stateHome, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let claim = try ZmxTestWorkspace.claim(stateHome)
    let claimedStateHome = try #require(claim)

    #expect(try ZmxTestWorkspace.claim(stateHome) == nil)
    #expect(FileManager.default.fileExists(atPath: claimedStateHome.path))
  }

  @Test
  func interruptedClaimIsReaped() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let stateHome = temporaryDirectory.appendingPathComponent("supaterm-ui-dead", isDirectory: true)
    try FileManager.default.createDirectory(at: stateHome, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    try writeOwner(ZmxTestWorkspace.Owner(runnerProcess: deadProcess, appProcess: nil), to: stateHome)
    let claim = try ZmxTestWorkspace.claim(stateHome, reaperProcess: deadProcess)
    let claimedStateHome = try #require(claim)
    let cleanedInstances = Mutex([String]())

    try ZmxTestWorkspace.reapAbandoned(
      in: temporaryDirectory,
      stateHomePrefix: "supaterm-ui-",
      instanceNamePrefix: "ui-",
      cleanupInstance: { instanceName in
        cleanedInstances.withLock { $0.append(instanceName) }
      }
    )

    #expect(cleanedInstances.withLock { $0 } == ["ui-dead"])
    #expect(!FileManager.default.fileExists(atPath: claimedStateHome.path))
  }

  @Test
  func repeatedClaimReplacesPriorMetadata() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let stateHome = temporaryDirectory.appendingPathComponent("supaterm-ui-dead", isDirectory: true)
    try FileManager.default.createDirectory(at: stateHome, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }

    let firstClaim = try #require(
      try ZmxTestWorkspace.claim(stateHome, reaperProcess: deadProcess)
    )
    let secondClaim = try #require(
      try ZmxTestWorkspace.claim(firstClaim, reaperProcess: deadProcess)
    )

    #expect(
      secondClaim.lastPathComponent.components(separatedBy: ZmxTestWorkspace.claimMarker).count == 2
    )
  }

  @Test
  func activeClaimIsNotReaped() throws {
    let temporaryDirectory = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let stateHome = temporaryDirectory.appendingPathComponent("supaterm-ui-dead", isDirectory: true)
    try FileManager.default.createDirectory(at: stateHome, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: temporaryDirectory) }
    try writeOwner(ZmxTestWorkspace.Owner(runnerProcess: deadProcess, appProcess: nil), to: stateHome)
    let claim = try ZmxTestWorkspace.claim(stateHome)
    let claimedStateHome = try #require(claim)
    let cleanedInstances = Mutex([String]())

    try ZmxTestWorkspace.reapAbandoned(
      in: temporaryDirectory,
      stateHomePrefix: "supaterm-ui-",
      instanceNamePrefix: "ui-",
      cleanupInstance: { instanceName in
        cleanedInstances.withLock { $0.append(instanceName) }
      }
    )

    #expect(cleanedInstances.withLock { $0 }.isEmpty)
    #expect(FileManager.default.fileExists(atPath: claimedStateHome.path))
  }

  @Test
  func runHandlesOutputLargerThanPipeBuffers() throws {
    let output = try ZmxTestSessionCleaner.run(
      executableURL: URL(fileURLWithPath: "/bin/sh"),
      arguments: ["-c", "yes output | head -c 131072; yes error | head -c 131072 >&2"],
      environment: ProcessInfo.processInfo.environment
    )

    #expect(output.utf8.count == 131_072)
  }

  @Test
  func runTimesOut() {
    #expect(throws: ZmxTestCleanupError.self) {
      try ZmxTestSessionCleaner.run(
        executableURL: URL(fileURLWithPath: "/bin/sleep"),
        arguments: ["10"],
        environment: ProcessInfo.processInfo.environment,
        timeout: 0.01
      )
    }
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
    let cleaner = ZmxTestSessionCleaner(
      executableURL: zmxExecutableURL,
      instanceName: instanceName,
      directory: workspace.zmxDirectory.path
    )
    defer { try? cleaner.cleanup() }
    _ = try ZmxTestSessionCleaner.run(
      executableURL: zmxExecutableURL,
      arguments: ["run", sessionID, "-d", "/bin/sleep", "60"],
      environment: ZmxTestSessionCleaner.environment(directory: workspace.zmxDirectory.path)
    )
    let sessions = try ZmxTestSessionCleaner.run(
      executableURL: zmxExecutableURL,
      arguments: ["ls", "--short"],
      environment: ZmxTestSessionCleaner.environment(directory: workspace.zmxDirectory.path)
    )
    #expect(sessions.split(whereSeparator: \.isNewline).contains(Substring(sessionID)))

    try workspace.cleanup()
    #expect(!FileManager.default.fileExists(atPath: stateHome.path))
    #expect(!FileManager.default.fileExists(atPath: workspace.zmxDirectory.path))

    let abandonedStateHome = temporaryDirectory.appendingPathComponent(
      "supaterm-ui-abandoned",
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: abandonedStateHome, withIntermediateDirectories: true)
    try writeOwner(
      ZmxTestWorkspace.Owner(runnerProcess: deadProcess, appProcess: nil),
      to: abandonedStateHome
    )
    try ZmxTestWorkspace.reapAbandoned(
      in: temporaryDirectory,
      stateHomePrefix: "supaterm-ui-",
      instanceNamePrefix: "ui-",
      zmxExecutableURL: zmxExecutableURL
    )
    #expect(!FileManager.default.fileExists(atPath: abandonedStateHome.path))
  }

  @Test
  func stateCleanupRequiresTheAppToRemoveItsZmxDirectory() throws {
    let stateHome = FileManager.default.temporaryDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let workspace = try ZmxTestWorkspace(
      stateHome: stateHome,
      instanceName: "ui-\(UUID().uuidString)",
      zmxExecutableURL: URL(fileURLWithPath: "/usr/bin/true")
    )
    try FileManager.default.createDirectory(
      at: workspace.zmxDirectory,
      withIntermediateDirectories: true
    )
    defer {
      try? FileManager.default.removeItem(at: workspace.zmxDirectory)
      try? FileManager.default.removeItem(at: stateHome)
    }

    #expect(throws: ZmxTestCleanupError.self) {
      try workspace.removeStateAfterAppCleanup()
    }

    try FileManager.default.removeItem(at: workspace.zmxDirectory)
    try workspace.removeStateAfterAppCleanup()
    #expect(!FileManager.default.fileExists(atPath: stateHome.path))
  }

  private var zmxExecutableURL: URL {
    Bundle(for: ZmxTestBundleToken.self).bundleURL
      .deletingLastPathComponent()
      .appendingPathComponent("supaterm.app/Contents/Helpers/zmx")
  }

  private var deadProcess: ZmxTestWorkspace.ProcessIdentity {
    ZmxTestWorkspace.ProcessIdentity(
      processID: .max,
      startTimeSeconds: .max,
      startTimeMicroseconds: .max
    )
  }

  private func writeOwner(_ owner: ZmxTestWorkspace.Owner, to stateHome: URL) throws {
    try JSONEncoder().encode(owner).write(
      to: stateHome.appendingPathComponent(ZmxTestWorkspace.ownerFilename),
      options: .atomic
    )
  }

  private func readOwner(from stateHome: URL) throws -> ZmxTestWorkspace.Owner {
    try JSONDecoder().decode(
      ZmxTestWorkspace.Owner.self,
      from: Data(contentsOf: stateHome.appendingPathComponent(ZmxTestWorkspace.ownerFilename))
    )
  }

  private func launchSleepProcess() throws -> Process {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/sleep")
    process.arguments = ["60"]
    try process.run()
    return process
  }

  private func stop(_ process: Process) {
    if process.isRunning {
      process.terminate()
    }
    process.waitUntilExit()
  }
}

private final class ZmxTestBundleToken {}
