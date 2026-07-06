import Darwin
import Foundation
import SupatermCLIShared

@testable import SPCLI

struct SupatermE2EError: Error, CustomStringConvertible {
  let description: String

  init(_ description: String) {
    self.description = description
  }
}

final class SupatermE2EApp: @unchecked Sendable {
  let stateHome: URL
  private let process: Process
  private let client: SPSocketClient
  private let logURL: URL
  private let zmxDirectory: URL

  static func launch() async throws -> SupatermE2EApp {
    let app = try SupatermE2EApp()
    try await app.waitUntil("the app socket accepts ping", timeout: 90) {
      (try? app.client.send(.ping()))?.ok == true
    }
    return app
  }

  private init() throws {
    let executable = Self.productsDirectory
      .appendingPathComponent("supaterm.app/Contents/MacOS/supaterm")
    guard FileManager.default.isExecutableFile(atPath: executable.path) else {
      throw SupatermE2EError(
        "Missing \(executable.path). Build the supatermE2E scheme (make mac-test-e2e) first."
      )
    }

    let instanceName = "e2e-\(UUID().uuidString.prefix(8).lowercased())"
    stateHome = FileManager.default.temporaryDirectory
      .appendingPathComponent("supaterm-\(instanceName)", isDirectory: true)
    let home = stateHome.appendingPathComponent("home", isDirectory: true)
    zmxDirectory = stateHome.appendingPathComponent("zmx", isDirectory: true)
    logURL = stateHome.appendingPathComponent("app.log", isDirectory: false)

    try FileManager.default.createDirectory(at: home, withIntermediateDirectories: true)
    try FileManager.default.createDirectory(at: zmxDirectory, withIntermediateDirectories: true)
    FileManager.default.createFile(atPath: home.appendingPathComponent(".zshrc").path, contents: nil)
    FileManager.default.createFile(atPath: logURL.path, contents: nil)

    let environment = [
      "HOME": home.path,
      "LOGNAME": NSUserName(),
      "PATH": "/usr/bin:/bin:/usr/sbin:/sbin",
      "SHELL": "/bin/zsh",
      "SUPATERM_TEST_MODE": "1",
      "USER": NSUserName(),
      "ZMX_DIR": zmxDirectory.path,
      SupatermCLIEnvironment.instanceNameKey: instanceName,
      SupatermCLIEnvironment.stateHomeKey: stateHome.path,
    ]

    let log = try FileHandle(forWritingTo: logURL)
    process = Process()
    process.executableURL = executable
    process.environment = environment
    process.currentDirectoryURL = home
    process.standardOutput = log
    process.standardError = log
    try process.run()

    let socketPath = SupatermSocketPath.managedSocketURL(
      instanceName: instanceName,
      processID: process.processIdentifier,
      environment: environment
    ).path
    client = try SPSocketClient(path: socketPath, connectRetryTimeout: 0.2)
  }

  private static var productsDirectory: URL {
    final class BundleToken {}
    return Bundle(for: BundleToken.self).bundleURL.deletingLastPathComponent()
  }

  func send<Result: Decodable>(
    _ request: SupatermSocketRequest,
    as type: Result.Type
  ) throws -> Result {
    let response = try client.send(request)
    guard response.ok else {
      throw SupatermE2EError(
        "\(request.method) failed: \(response.error?.message ?? "unknown error")"
      )
    }
    return try response.decodeResult(type)
  }

  func debugSnapshot() throws -> SupatermAppDebugSnapshot {
    try send(.debug(SupatermDebugRequest()), as: SupatermAppDebugSnapshot.self)
  }

  func capture(_ target: SupatermPaneTargetRequest) throws -> String {
    try send(
      .capturePane(SupatermCapturePaneRequest(target: target)),
      as: SupatermCapturePaneResult.self
    ).text
  }

  func waitUntil(
    _ label: String,
    timeout: TimeInterval = 30,
    _ condition: () throws -> Bool
  ) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
      if try condition() {
        return
      }
      try await Task.sleep(for: .milliseconds(100))
    }
    throw SupatermE2EError("Timed out waiting until \(label).\n\(diagnostics())")
  }

  func waitForCapture(
    _ target: SupatermPaneTargetRequest,
    contains marker: String
  ) async throws {
    var lastText = ""
    do {
      try await waitUntil("the pane text contains '\(marker)'") {
        lastText = (try? capture(target)) ?? lastText
        return lastText.replacingOccurrences(of: "\n", with: "").contains(marker)
      }
    } catch {
      throw SupatermE2EError("\(error)\n--- last pane capture ---\n\(lastText)")
    }
  }

  func waitForReadyPane(_ target: SupatermPaneTargetRequest) async throws {
    try await waitUntil("the pane is ready to capture") {
      let health = try send(
        .paneHealth(SupatermPaneHealthRequest(target: target)),
        as: SupatermPaneHealthResult.self
      )
      return health.isReady && health.canCaptureText
    }
  }

  func terminate() {
    process.terminate()
    let deadline = Date().addingTimeInterval(5)
    while process.isRunning, Date() < deadline {
      Thread.sleep(forTimeInterval: 0.1)
    }
    if process.isRunning {
      kill(process.processIdentifier, SIGKILL)
    }
    process.waitUntilExit()

    let pkill = Process()
    pkill.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
    pkill.arguments = ["-f", zmxDirectory.path]
    try? pkill.run()
    pkill.waitUntilExit()
  }

  private func diagnostics() -> String {
    let log = (try? String(contentsOf: logURL, encoding: .utf8)) ?? ""
    let tail = log.split(separator: "\n").suffix(40).joined(separator: "\n")
    return "--- app log tail ---\n\(tail)"
  }
}
