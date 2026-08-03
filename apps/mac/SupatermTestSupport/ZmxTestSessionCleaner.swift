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
  private let run: Run

  init(executableURL: URL, instanceName: String) {
    self.init(instanceName: instanceName) { arguments, environment in
      try Self.run(executableURL: executableURL, arguments: arguments, environment: environment)
    }
  }

  init(instanceName: String, run: @escaping Run) {
    instancePrefix = ZmxSessionID.namespacePrefix(
      environment: [SupatermCLIEnvironment.instanceNameKey: instanceName]
    )
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
    Self.environment
  }

  static var environment: [String: String] {
    var environment = ProcessInfo.processInfo.environment
    environment[ZmxEnvironment.directoryKey] = ZmxSocketBudget.socketDir()
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
    let runnerProcessID: Int32
    let appProcess: ProcessIdentity?
  }

  private let stateHome: URL
  private let cleaner: ZmxTestSessionCleaner

  init(stateHome: URL, instanceName: String, zmxExecutableURL: URL) throws {
    self.stateHome = stateHome
    cleaner = ZmxTestSessionCleaner(executableURL: zmxExecutableURL, instanceName: instanceName)
    try FileManager.default.createDirectory(at: stateHome, withIntermediateDirectories: true)
    try writeOwner(Owner(runnerProcessID: getpid(), appProcess: nil))
  }

  func recordApp(_ process: Process) throws {
    let processID = process.processIdentifier
    guard let appProcess = Self.processIdentity(processID: processID) else {
      throw ZmxTestCleanupError.processIdentityUnavailable(processID)
    }
    try writeOwner(Owner(runnerProcessID: getpid(), appProcess: appProcess))
  }

  func cleanup() throws {
    if let appProcess = try readOwner().appProcess {
      try Self.terminateProcess(appProcess)
    }
    try cleaner.cleanup()
    if FileManager.default.fileExists(atPath: stateHome.path) {
      try FileManager.default.removeItem(at: stateHome)
    }
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
      processIsRunning: processIsRunning,
      cleanupInstance: { instanceName in
        try ZmxTestSessionCleaner(
          executableURL: zmxExecutableURL,
          instanceName: instanceName
        ).cleanup()
      }
    )
  }

  static func reapAbandoned(
    in temporaryDirectory: URL,
    stateHomePrefix: String,
    instanceNamePrefix: String,
    processIsRunning: (Int32) -> Bool,
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
      guard (try? stateHome.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else {
        continue
      }
      let ownerURL = stateHome.appendingPathComponent(ownerFilename)
      guard
        let data = try? Data(contentsOf: ownerURL),
        let owner = try? JSONDecoder().decode(Owner.self, from: data),
        !processIsRunning(owner.runnerProcessID)
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

  static func claim(_ stateHome: URL, fileManager: FileManager = .default) throws -> URL? {
    let claimedStateHome = stateHome.deletingLastPathComponent().appendingPathComponent(
      "\(stateHome.lastPathComponent)\(claimMarker)\(UUID().uuidString)",
      isDirectory: true
    )
    do {
      try fileManager.moveItem(at: stateHome, to: claimedStateHome)
      return claimedStateHome
    } catch let error as CocoaError where error.code == .fileNoSuchFile {
      return nil
    }
  }

  private static func processIsRunning(_ processID: Int32) -> Bool {
    guard processID > 0 else { return false }
    if kill(processID, 0) == 0 { return true }
    return errno == EPERM
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
