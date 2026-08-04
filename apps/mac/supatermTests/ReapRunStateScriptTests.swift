import Foundation
import SupatermCLIShared
import SupatermSupport
import Testing

struct ReapRunStateScriptTests {
  @Test
  func reapsAbandonedRunsAndSparesLiveOnes() throws {
    let root = try makeDirectory(URL(fileURLWithPath: "/tmp/spt-reap-\(token)", isDirectory: true))
    let unrelatedZmxDirectory = try makeDirectory(
      URL(fileURLWithPath: "/tmp/spt-keep-\(token)", isDirectory: true)
    )
    let abandoned = try makeDirectory(root.appendingPathComponent("abandoned", isDirectory: true))
    let live = try makeDirectory(root.appendingPathComponent("live", isDirectory: true))
    defer {
      for directory in [abandoned, live] {
        try? ZmxTestSessionCleaner(directory: directory.appendingPathComponent("zmx").path).cleanup()
      }
      try? ZmxTestSessionCleaner(directory: unrelatedZmxDirectory.path).cleanup()
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: unrelatedZmxDirectory)
    }

    let abandonedSession = try startSession(in: abandoned, executable: zmxExecutableURL)
    let unrelatedSession = try startSession(
      in: unrelatedZmxDirectory,
      executable: zmxExecutableURL,
      zmxDirectory: unrelatedZmxDirectory
    )
    let appStandIn = try makeExecutableCopy(named: "supaterm", in: root)
    let liveSession = try startSession(in: live, executable: appStandIn)

    try run(URL(fileURLWithPath: "/bin/bash"), arguments: [scriptURL.path, root.path])

    #expect(!ZmxTestWorkspace.processMatches(abandonedSession))
    #expect(!FileManager.default.fileExists(atPath: abandoned.path))
    #expect(ZmxTestWorkspace.processMatches(liveSession))
    #expect(FileManager.default.fileExists(atPath: live.path))
    #expect(ZmxTestWorkspace.processMatches(unrelatedSession))
  }

  /// `ps -E` runs the environment on from the arguments, so an argument naming a
  /// run must not cost an unrelated process group its life.
  @Test
  func sparesAProcessThatOnlyNamesTheDirectoryInItsArguments() throws {
    let root = try makeDirectory(URL(fileURLWithPath: "/tmp/spt-reap-\(token)", isDirectory: true))
    let unrelatedZmxDirectory = try makeDirectory(
      URL(fileURLWithPath: "/tmp/spt-keep-\(token)", isDirectory: true)
    )
    let decoy = try makeDirectory(root.appendingPathComponent("decoy", isDirectory: true))
    defer {
      try? ZmxTestSessionCleaner(directory: unrelatedZmxDirectory.path).cleanup()
      try? FileManager.default.removeItem(at: root)
      try? FileManager.default.removeItem(at: unrelatedZmxDirectory)
    }

    let decoyDirectory = decoy.appendingPathComponent("zmx", isDirectory: true).path
    let session = try startSession(
      in: decoy,
      executable: zmxExecutableURL,
      zmxDirectory: unrelatedZmxDirectory,
      command: ["/bin/sh", "-c", "sleep 600", "\(ZmxEnvironment.directoryKey)=\(decoyDirectory)"]
    )

    try run(URL(fileURLWithPath: "/bin/bash"), arguments: [scriptURL.path, root.path])

    #expect(ZmxTestWorkspace.processMatches(session))
  }

  /// Only a zmx daemon belongs to a run, so a process that merely inherited the
  /// run's `ZMX_DIR` keeps its life.
  @Test
  func sparesAProcessThatIsNotAZmxSession() throws {
    let root = try makeDirectory(URL(fileURLWithPath: "/tmp/spt-reap-\(token)", isDirectory: true))
    let stateHome = try makeDirectory(root.appendingPathComponent("tool", isDirectory: true))
    defer {
      try? ZmxTestSessionCleaner(directory: stateHome.appendingPathComponent("zmx").path).cleanup()
      try? FileManager.default.removeItem(at: root)
    }

    let tool = try makeExecutableCopy(named: "unrelated-tool", in: root)
    let session = try startSession(in: stateHome, executable: tool)

    try run(URL(fileURLWithPath: "/bin/bash"), arguments: [scriptURL.path, root.path])

    #expect(ZmxTestWorkspace.processMatches(session))
  }

  private var token: String {
    UUID().uuidString.prefix(8).lowercased()
  }

  private var scriptURL: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("scripts/reap-run-state.sh")
  }

  private var zmxExecutableURL: URL {
    Bundle(for: ReapRunStateScriptBundleToken.self).bundleURL
      .deletingLastPathComponent()
      .appendingPathComponent("supaterm.app/Contents/Helpers/zmx")
  }

  /// `ucomm` reports the executable name, so a renamed copy of a binary that
  /// outlives its launcher stands in for any process the reaper has to weigh.
  private func makeExecutableCopy(named name: String, in directory: URL) throws -> URL {
    let executable = directory.appendingPathComponent(name, isDirectory: false)
    try FileManager.default.copyItem(at: zmxExecutableURL, to: executable)
    return executable
  }

  private func makeDirectory(_ url: URL) throws -> URL {
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
  }

  private func startSession(
    in stateHome: URL,
    executable: URL,
    zmxDirectory: URL? = nil,
    command: [String] = ["/bin/sleep", "600"]
  ) throws -> ZmxTestWorkspace.ProcessIdentity {
    let zmxDirectory = try makeDirectory(
      zmxDirectory ?? stateHome.appendingPathComponent("zmx", isDirectory: true)
    )
    var environment = ProcessInfo.processInfo.environment
    environment[SupatermCLIEnvironment.stateHomeKey] = stateHome.path
    environment[ZmxEnvironment.directoryKey] = zmxDirectory.path
    environment[ZmxEnvironment.sessionKey] = ""
    environment[ZmxEnvironment.sessionPrefixKey] = ""
    try run(
      executable,
      arguments: ["run", "spt-reap-\(token)", "-d"] + command,
      environment: environment
    )

    let deadline = Date().addingTimeInterval(10)
    while Date() < deadline {
      if let processID = ZmxTestProcessTable.sessionProcessIDs(directory: zmxDirectory.path).first,
        let session = ZmxTestWorkspace.processIdentity(processID: processID)
      {
        return session
      }
      Thread.sleep(forTimeInterval: 0.05)
    }
    throw ReapRunStateScriptError("no zmx session appeared in \(zmxDirectory.path)")
  }

  private func run(
    _ executable: URL,
    arguments: [String],
    environment: [String: String]? = nil
  ) throws {
    let process = Process()
    process.executableURL = executable
    process.arguments = arguments
    process.environment = environment
    process.standardOutput = FileHandle.nullDevice
    process.standardError = FileHandle.nullDevice
    try process.run()
    process.waitUntilExit()
    guard process.terminationStatus == 0 else {
      throw ReapRunStateScriptError(
        "\(executable.lastPathComponent) exited with \(process.terminationStatus)"
      )
    }
  }
}

private struct ReapRunStateScriptError: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}

private final class ReapRunStateScriptBundleToken {}
