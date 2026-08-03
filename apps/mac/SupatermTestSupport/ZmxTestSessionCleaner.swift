import Darwin
import Foundation
import SupatermCLIShared
import SupatermSupport

nonisolated enum ZmxTestCleanupError: Error, CustomStringConvertible {
  case commandFailed(arguments: [String], status: Int32, stderr: String)
  case sessionsRemain([String])

  var description: String {
    switch self {
    case .commandFailed(let arguments, let status, let stderr):
      return "zmx \(arguments.joined(separator: " ")) failed with status \(status): \(stderr)"
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
    environment: [String: String]
  ) throws -> String {
    let stdout = Pipe()
    let stderr = Pipe()
    let process = Process()
    process.executableURL = executableURL
    process.arguments = arguments
    process.environment = environment
    process.standardOutput = stdout
    process.standardError = stderr
    try process.run()
    process.waitUntilExit()

    let output =
      String(
        data: stdout.fileHandleForReading.readDataToEndOfFile(),
        encoding: .utf8
      ) ?? ""
    guard process.terminationStatus == 0 else {
      let error =
        String(
          data: stderr.fileHandleForReading.readDataToEndOfFile(),
          encoding: .utf8
        ) ?? ""
      throw ZmxTestCleanupError.commandFailed(
        arguments: arguments,
        status: process.terminationStatus,
        stderr: error.trimmingCharacters(in: .whitespacesAndNewlines)
      )
    }
    return output
  }
}

nonisolated struct ZmxTestWorkspace: Sendable {
  static let ownerFilename = ".supaterm-test-owner"

  private let stateHome: URL
  private let cleaner: ZmxTestSessionCleaner

  init(stateHome: URL, instanceName: String, zmxExecutableURL: URL) throws {
    self.stateHome = stateHome
    cleaner = ZmxTestSessionCleaner(executableURL: zmxExecutableURL, instanceName: instanceName)
    try FileManager.default.createDirectory(at: stateHome, withIntermediateDirectories: true)
    try String(getpid()).write(
      to: stateHome.appendingPathComponent(Self.ownerFilename),
      atomically: true,
      encoding: .utf8
    )
  }

  func cleanup() throws {
    try cleaner.cleanup()
    if FileManager.default.fileExists(atPath: stateHome.path) {
      try FileManager.default.removeItem(at: stateHome)
    }
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
    fileManager: FileManager = .default,
    processIsRunning: (Int32) -> Bool,
    cleanupInstance: (String) throws -> Void
  ) throws {
    let urls = try fileManager.contentsOfDirectory(
      at: temporaryDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )
    for stateHome in urls.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
      let name = stateHome.lastPathComponent
      guard name.hasPrefix(stateHomePrefix) else { continue }
      guard try stateHome.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else { continue }
      let ownerURL = stateHome.appendingPathComponent(ownerFilename)
      guard
        let owner = try? String(contentsOf: ownerURL, encoding: .utf8),
        let processID = Int32(owner.trimmingCharacters(in: .whitespacesAndNewlines)),
        !processIsRunning(processID)
      else {
        continue
      }
      let suffix = name.dropFirst(stateHomePrefix.count)
      try cleanupInstance(instanceNamePrefix + suffix)
      try fileManager.removeItem(at: stateHome)
    }
  }

  private static func processIsRunning(_ processID: Int32) -> Bool {
    guard processID > 0 else { return false }
    if kill(processID, 0) == 0 { return true }
    return errno == EPERM
  }
}
