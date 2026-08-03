import Darwin
import Foundation
import SupatermCLIShared
import SupatermSupport

nonisolated enum ZmxTestCleanupError: Error, CustomStringConvertible {
  case commandFailed(arguments: [String], status: Int32, stderr: String)
  case commandTimedOut(arguments: [String])
  case processDidNotExit(Int32)
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

  struct Owner: Codable, Sendable {
    let runnerProcessID: Int32
    let appProcessID: Int32?
  }

  private let stateHome: URL
  private let cleaner: ZmxTestSessionCleaner

  init(stateHome: URL, instanceName: String, zmxExecutableURL: URL) throws {
    self.stateHome = stateHome
    cleaner = ZmxTestSessionCleaner(executableURL: zmxExecutableURL, instanceName: instanceName)
    try FileManager.default.createDirectory(at: stateHome, withIntermediateDirectories: true)
    try writeOwner(Owner(runnerProcessID: getpid(), appProcessID: nil))
  }

  func recordAppProcessID(_ processID: Int32) throws {
    try writeOwner(Owner(runnerProcessID: getpid(), appProcessID: processID))
  }

  func cleanup() throws {
    if let processID = try readOwner().appProcessID {
      try Self.terminateProcess(processID)
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
      let suffix = name.dropFirst(stateHomePrefix.count)
      guard let claimedStateHome = try claim(stateHome, fileManager: fileManager) else { continue }
      do {
        if let appProcessID = owner.appProcessID {
          try terminateProcess(appProcessID)
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
      ".supaterm-test-reap-\(UUID().uuidString)",
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

  private static func terminateProcess(_ processID: Int32) throws {
    guard processIsRunning(processID) else { return }
    try send(SIGTERM, to: processID)
    if waitForExit(processID, timeout: 5) { return }
    try send(SIGKILL, to: processID)
    guard waitForExit(processID, timeout: 2) else {
      throw ZmxTestCleanupError.processDidNotExit(processID)
    }
  }

  private static func waitForExit(_ processID: Int32, timeout: TimeInterval) -> Bool {
    let deadline = Date().addingTimeInterval(timeout)
    while processIsRunning(processID), Date() < deadline {
      Thread.sleep(forTimeInterval: 0.05)
    }
    return !processIsRunning(processID)
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
