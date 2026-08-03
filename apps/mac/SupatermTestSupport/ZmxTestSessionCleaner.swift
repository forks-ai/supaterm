import Darwin
import Foundation
import SupatermCLIShared
import SupatermSupport

nonisolated enum ZmxTestCleanupError: Error, CustomStringConvertible {
  case commandFailed(arguments: [String], status: Int32, stderr: String)
  case commandTimedOut(arguments: [String])
  case processDidNotExit(Int32)
  case processIdentityUnavailable(Int32)
  case processSignalFailed(processID: Int32, signal: Int32, errorCode: Int32)
  case sessionsRemain([String])

  var description: String {
    switch self {
    case .commandFailed(let arguments, let status, let stderr):
      return "zmx \(arguments.joined(separator: " ")) failed with status \(status): \(stderr)"
    case .commandTimedOut(let arguments):
      return "zmx \(arguments.joined(separator: " ")) timed out"
    case .processDidNotExit(let processID):
      return "process \(processID) did not exit"
    case .processIdentityUnavailable(let processID):
      return "process \(processID) identity is unavailable"
    case .processSignalFailed(let processID, let signal, let errorCode):
      return "signal \(signal) failed for process \(processID) with error \(errorCode)"
    case .sessionsRemain(let sessionIDs):
      return "zmx sessions remain: \(sessionIDs.joined(separator: ", "))"
    }
  }
}

nonisolated struct ZmxTestSessionCleaner: Sendable {
  typealias Run = @Sendable (_ arguments: [String], _ environment: [String: String]) throws -> String

  private let instancePrefix: String
  private let directory: String
  private let run: Run

  init(executableURL: URL, instanceName: String, directory: String) {
    self.init(instanceName: instanceName, directory: directory) { arguments, environment in
      try Self.run(executableURL: executableURL, arguments: arguments, environment: environment)
    }
  }

  init(instanceName: String, directory: String, run: @escaping Run) {
    instancePrefix = ZmxSessionID.namespacePrefix(
      environment: [SupatermCLIEnvironment.instanceNameKey: instanceName]
    )
    self.directory = directory
    self.run = run
  }

  func cleanup() throws {
    let sessionIDs = try listSessions()
    guard !sessionIDs.isEmpty else { return }

    _ = try run(["kill"] + sessionIDs, environment)

    let remainingSessionIDs = try listSessions()
    guard remainingSessionIDs.isEmpty else {
      throw ZmxTestCleanupError.sessionsRemain(remainingSessionIDs)
    }
  }

  private var environment: [String: String] {
    Self.environment(directory: directory)
  }

  static func environment(directory: String) -> [String: String] {
    var environment = ProcessInfo.processInfo.environment
    environment[ZmxEnvironment.directoryKey] = directory
    environment[ZmxEnvironment.sessionKey] = ""
    environment[ZmxEnvironment.sessionPrefixKey] = ""
    return environment
  }

  private func listSessions() throws -> [String] {
    try run(["ls", "--short"], environment)
      .split(whereSeparator: \.isNewline)
      .map { $0.trimmingCharacters(in: .whitespaces) }
      .filter { $0.hasPrefix(instancePrefix) }
  }

  static func run(
    executableURL: URL,
    arguments: [String],
    environment: [String: String],
    timeout: TimeInterval = 10
  ) throws -> String {
    let fileManager = FileManager.default
    let outputDirectory = fileManager.temporaryDirectory.appendingPathComponent(
      "supaterm-zmx-output-\(UUID().uuidString)",
      isDirectory: true
    )
    try fileManager.createDirectory(at: outputDirectory, withIntermediateDirectories: false)
    defer { try? fileManager.removeItem(at: outputDirectory) }

    let stdoutURL = outputDirectory.appendingPathComponent("stdout")
    let stderrURL = outputDirectory.appendingPathComponent("stderr")
    try Data().write(to: stdoutURL)
    try Data().write(to: stderrURL)
    let stdout = try FileHandle(forWritingTo: stdoutURL)
    let stderr = try FileHandle(forWritingTo: stderrURL)
    defer {
      try? stdout.close()
      try? stderr.close()
    }

    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.environment = environment
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    guard Self.waitForExit(process, timeout: timeout) else {
      process.terminate()
      if Self.waitForExit(process, timeout: 0.5) == false {
        kill(process.processIdentifier, SIGKILL)
        _ = Self.waitForExit(process, timeout: 0.5)
      }
      throw ZmxTestCleanupError.commandTimedOut(arguments: arguments)
    }

    try stdout.close()
    try stderr.close()

    let outputData = try Data(contentsOf: stdoutURL)
    let output = String(bytes: outputData, encoding: .utf8) ?? ""
    guard process.terminationStatus == 0 else {
      let errorData = try Data(contentsOf: stderrURL)
      let error = String(bytes: errorData, encoding: .utf8) ?? ""
      throw ZmxTestCleanupError.commandFailed(
        arguments: arguments,
        status: process.terminationStatus,
        stderr: error.trimmingCharacters(in: .whitespacesAndNewlines)
      )
    }
    return output
  }

  private static func waitForExit(_ process: Process, timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while process.isRunning, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.01)
    }
    return !process.isRunning
  }
}

nonisolated struct ZmxTestWorkspace: Sendable {
  static let ownerFilename = ".supaterm-test-owner"
  static let claimMarker = ".supaterm-test-reap-"

  struct ProcessIdentity: Codable, Equatable, Sendable {
    let processID: Int32
    let startTimeSeconds: UInt64
    let startTimeMicroseconds: UInt64
  }

  struct Owner: Codable, Sendable {
    let runnerProcess: ProcessIdentity
    let appProcess: ProcessIdentity?
  }

  private let stateHome: URL
  private let cleaner: ZmxTestSessionCleaner
  let zmxDirectory: URL

  init(stateHome: URL, instanceName: String, zmxExecutableURL: URL) throws {
    self.stateHome = stateHome
    zmxDirectory = Self.zmxDirectory(instanceName: instanceName)
    cleaner = ZmxTestSessionCleaner(
      executableURL: zmxExecutableURL,
      instanceName: instanceName,
      directory: zmxDirectory.path
    )
    let runnerProcess = try Self.requiredProcessIdentity(processID: getpid())
    try FileManager.default.createDirectory(at: stateHome, withIntermediateDirectories: true)
    try writeOwner(Owner(runnerProcess: runnerProcess, appProcess: nil))
  }

  func recordApp(_ process: Process) throws {
    let appProcess = try Self.requiredProcessIdentity(processID: process.processIdentifier)
    try writeOwner(Owner(runnerProcess: readOwner().runnerProcess, appProcess: appProcess))
  }

  func cleanup() throws {
    if let appProcess = try readOwner().appProcess {
      try Self.terminateProcess(appProcess)
    }
    try cleaner.cleanup()
    try Self.removeIfPresent(zmxDirectory)
    try Self.removeIfPresent(stateHome)
  }

  private var ownerURL: URL {
    stateHome.appendingPathComponent(Self.ownerFilename)
  }

  private func readOwner() throws -> Owner {
    try JSONDecoder().decode(Owner.self, from: Data(contentsOf: ownerURL))
  }

  private func writeOwner(_ owner: Owner) throws {
    try JSONEncoder().encode(owner).write(to: ownerURL, options: .atomic)
  }

  static func reapAbandoned(
    in temporaryDirectory: URL,
    stateHomePrefix: String,
    instanceNamePrefix: String,
    zmxExecutableURL: URL
  ) throws {
    try reapAbandoned(
      in: temporaryDirectory,
      stateHomePrefix: stateHomePrefix,
      instanceNamePrefix: instanceNamePrefix,
      cleanupInstance: { instanceName in
        let directory = zmxDirectory(instanceName: instanceName)
        try ZmxTestSessionCleaner(
          executableURL: zmxExecutableURL,
          instanceName: instanceName,
          directory: directory.path
        ).cleanup()
        try removeIfPresent(directory)
      }
    )
  }

  static func reapAbandoned(
    in temporaryDirectory: URL,
    stateHomePrefix: String,
    instanceNamePrefix: String,
    cleanupInstance: (String) throws -> Void
  ) throws {
    let fileManager = FileManager.default
    let urls = try fileManager.contentsOfDirectory(
      at: temporaryDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )
    for stateHome in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
      let name = stateHome.lastPathComponent
      guard name.hasPrefix(stateHomePrefix) else { continue }
      if let reaperProcess = claimOwner(from: name), processMatches(reaperProcess) {
        continue
      }
      guard (try? stateHome.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
        continue
      }
      let ownerURL = stateHome.appendingPathComponent(ownerFilename)
      guard
        let data = try? Data(contentsOf: ownerURL),
        let owner = try? JSONDecoder().decode(Owner.self, from: data),
        !processMatches(owner.runnerProcess)
      else {
        continue
      }
      let suffixWithClaims = name.dropFirst(stateHomePrefix.count)
      let suffixEnd = suffixWithClaims.range(of: claimMarker)?.lowerBound ?? suffixWithClaims.endIndex
      let suffix = suffixWithClaims[..<suffixEnd]
      guard let claimedStateHome = try claim(stateHome, fileManager: fileManager) else { continue }
      do {
        if let appProcess = owner.appProcess {
          try terminateProcess(appProcess)
        }
        try cleanupInstance(instanceNamePrefix + suffix)
        try fileManager.removeItem(at: claimedStateHome)
      } catch {
        if !fileManager.fileExists(atPath: stateHome.path) {
          try? fileManager.moveItem(at: claimedStateHome, to: stateHome)
        }
        throw error
      }
    }
  }

  static func claim(
    _ stateHome: URL,
    reaperProcess: ProcessIdentity? = nil,
    fileManager: FileManager = .default
  ) throws -> URL? {
    let reaperProcess = try reaperProcess ?? requiredProcessIdentity(processID: getpid())
    let claimedStateHome = stateHome.deletingLastPathComponent().appendingPathComponent(
      "\(stateHome.lastPathComponent)\(claimMarker)\(reaperProcess.processID)-"
        + "\(reaperProcess.startTimeSeconds)-\(reaperProcess.startTimeMicroseconds)-" + UUID().uuidString,
      isDirectory: true
    )
    do {
      try fileManager.moveItem(at: stateHome, to: claimedStateHome)
      return claimedStateHome
    } catch let error as CocoaError where error.code == .fileNoSuchFile {
      return nil
    }
  }

  private static func claimOwner(from name: String) -> ProcessIdentity? {
    guard let markerRange = name.range(of: claimMarker, options: .backwards) else { return nil }
    let fields = name[markerRange.upperBound...].split(separator: "-", maxSplits: 3)
    guard
      fields.count == 4,
      let processID = Int32(fields[0]),
      let startTimeSeconds = UInt64(fields[1]),
      let startTimeMicroseconds = UInt64(fields[2])
    else {
      return nil
    }
    return ProcessIdentity(
      processID: processID,
      startTimeSeconds: startTimeSeconds,
      startTimeMicroseconds: startTimeMicroseconds
    )
  }

  private static func zmxDirectory(instanceName: String) -> URL {
    let instanceHash = ZmxSessionID.instanceHash(
      environment: [SupatermCLIEnvironment.instanceNameKey: instanceName]
    )
    return URL(fileURLWithPath: "/tmp", isDirectory: true)
      .appendingPathComponent("spt-z-\(instanceHash)", isDirectory: true)
  }

  private static func removeIfPresent(_ url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      try FileManager.default.removeItem(at: url)
    }
  }

  private static func terminateProcess(_ process: ProcessIdentity) throws {
    guard processMatches(process) else { return }
    try send(SIGTERM, to: process.processID)
    if waitForExit(process, timeout: 5) { return }
    guard processMatches(process) else { return }
    try send(SIGKILL, to: process.processID)
    guard waitForExit(process, timeout: 2) else {
      throw ZmxTestCleanupError.processDidNotExit(process.processID)
    }
  }

  private static func waitForExit(_ process: ProcessIdentity, timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while processMatches(process), Date() < deadline {
      Thread.sleep(forTimeInterval: 0.05)
    }
    return !processMatches(process)
  }

  private static func processMatches(_ process: ProcessIdentity) -> Bool {
    processIdentity(processID: process.processID) == process
  }

  private static func requiredProcessIdentity(processID: Int32) throws -> ProcessIdentity {
    guard let process = processIdentity(processID: processID) else {
      throw ZmxTestCleanupError.processIdentityUnavailable(processID)
    }
    return process
  }

  private static func processIdentity(processID: Int32) -> ProcessIdentity? {
    var info = proc_bsdinfo()
    let size = MemoryLayout<proc_bsdinfo>.size
    guard proc_pidinfo(processID, PROC_PIDTBSDINFO, 0, &info, Int32(size)) == Int32(size) else {
      return nil
    }
    return ProcessIdentity(
      processID: processID,
      startTimeSeconds: info.pbi_start_tvsec,
      startTimeMicroseconds: info.pbi_start_tvusec
    )
  }

  private static func send(_ signal: Int32, to processID: Int32) throws {
    guard kill(processID, signal) != 0 else { return }
    guard errno != ESRCH else { return }
    throw ZmxTestCleanupError.processSignalFailed(
      processID: processID,
      signal: signal,
      errorCode: errno
    )
  }
}
