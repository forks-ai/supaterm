import CustomDump
import Darwin
import Foundation
import Testing

@testable import SupatermCLIShared

struct SupatermTerminalStartupTests {
  @Test
  func argumentStartupCreatesPrivateOneShotTransport() throws {
    let fixture = try StartupTransportFixture()
    defer { fixture.remove() }
    let arguments = [
      fixture.cliURL.path,
      "",
      "two words",
      "'\"$`\\;|&<>(){}[]*?!#~",
      "line one\nline two",
      "雪",
      String(repeating: "long", count: 1_024),
    ]

    let prepared = try SupatermTerminalStartup.arguments(arguments).prepare(
      cliPath: fixture.cliURL.path,
      temporaryDirectory: fixture.rootURL
    )
    defer { prepared.cleanupToken.cleanup() }
    let directoryURL = prepared.cleanupDirectoryURL
    let payloadURL = directoryURL.appendingPathComponent("arguments.json")
    let launcherURL = directoryURL.appendingPathComponent("launch")

    #expect(prepared.initialInput == launcherURL.path + "\n")
    #expect(prepared.initialInput.utf8.count < 1_024)
    #expect(try permissions(of: directoryURL) == 0o700)
    #expect(try permissions(of: payloadURL) == 0o600)
    #expect(try permissions(of: launcherURL) == 0o700)
    expectNoDifference(
      try JSONDecoder().decode([String].self, from: Data(contentsOf: payloadURL)),
      arguments
    )

    prepared.cleanupToken.cleanup()
    #expect(!FileManager.default.fileExists(atPath: directoryURL.path))
  }

  @Test
  func argumentStartupRejectsInvalidInput() throws {
    let fixture = try StartupTransportFixture()
    defer { fixture.remove() }

    for arguments in [[], [""], [" \n "], [fixture.cliURL.path, "nul\0byte"]] {
      #expect(throws: SupatermTerminalStartupError.self) {
        try SupatermTerminalStartup.arguments(arguments).prepare(
          cliPath: fixture.cliURL.path,
          temporaryDirectory: fixture.rootURL
        )
      }
    }
    #expect(throws: SupatermTerminalStartupError.self) {
      try SupatermTerminalStartup.arguments([fixture.cliURL.path]).prepare(
        cliPath: "/does/not/exist",
        temporaryDirectory: fixture.rootURL
      )
    }
    #expect(throws: SupatermTerminalStartupError.self) {
      try SupatermTerminalStartup.arguments([
        fixture.cliURL.path,
        String(repeating: "x", count: SupatermTerminalStartup.maximumArgumentsPayloadSize),
      ]).prepare(
        cliPath: fixture.cliURL.path,
        temporaryDirectory: fixture.rootURL
      )
    }
  }

  @Test
  func cleanupDoesNotRemoveAReplacementDirectory() throws {
    let fixture = try StartupTransportFixture()
    defer { fixture.remove() }
    let prepared = try SupatermTerminalStartup.arguments([fixture.cliURL.path]).prepare(
      cliPath: fixture.cliURL.path,
      temporaryDirectory: fixture.rootURL
    )
    let directoryURL = prepared.cleanupDirectoryURL
    try FileManager.default.removeItem(at: directoryURL)
    try FileManager.default.createDirectory(
      at: directoryURL,
      withIntermediateDirectories: false,
      attributes: [.posixPermissions: 0o700]
    )

    prepared.cleanupToken.cleanup()

    #expect(FileManager.default.fileExists(atPath: directoryURL.path))
  }

  @Test
  func staleTransportReapingKeepsTheCurrentProcess() throws {
    let fixture = try StartupTransportFixture()
    defer { fixture.remove() }
    let staleURL = fixture.rootURL.appendingPathComponent(
      "supaterm-startup-999999-\(UUID().uuidString.lowercased())",
      isDirectory: true
    )
    let liveURL = fixture.rootURL.appendingPathComponent(
      "supaterm-startup-\(getpid())-\(UUID().uuidString.lowercased())",
      isDirectory: true
    )
    for url in [staleURL, liveURL] {
      try FileManager.default.createDirectory(
        at: url,
        withIntermediateDirectories: false,
        attributes: [.posixPermissions: 0o700]
      )
    }

    SupatermTerminalStartup.reapStaleTransports(temporaryDirectory: fixture.rootURL)

    #expect(!FileManager.default.fileExists(atPath: staleURL.path))
    #expect(FileManager.default.fileExists(atPath: liveURL.path))
  }

  @Test
  func longScriptStartupUsesShortPrivateSource() throws {
    let fixture = try StartupTransportFixture()
    defer { fixture.remove() }
    let script = "value='\(String(repeating: "x", count: 2_048))'\nprintf ready\n"
    let prepared = try SupatermTerminalStartup.script(script).prepare(
      cliPath: nil,
      shellPath: "/bin/zsh",
      temporaryDirectory: fixture.rootURL
    )
    defer { prepared.cleanupToken.cleanup() }
    let directoryURL = prepared.cleanupDirectoryURL
    let scriptURL = directoryURL.appendingPathComponent("script")

    #expect(prepared.initialInput == ". \(scriptURL.path)\n")
    #expect(prepared.initialInput.utf8.count < 1_024)
    #expect(!prepared.initialInput.contains(String(repeating: "x", count: 128)))
    #expect(try permissions(of: directoryURL) == 0o700)
    #expect(try permissions(of: scriptURL) == 0o600)
    #expect(try String(contentsOf: scriptURL, encoding: .utf8).hasSuffix(script))
  }

  @Test
  func scriptStartupUsesTheShellsSourceSyntax() throws {
    let fixture = try StartupTransportFixture()
    defer { fixture.remove() }
    for (name, command, fileName) in [
      ("zsh", ".", "script"),
      ("tcsh", "source", "script"),
      ("fish", "source", "script"),
      ("nu", "source", "script.nu"),
      ("elvish", "eval (slurp", "script"),
    ] {
      let shellURL = try fixture.executable(named: name)
      let prepared = try SupatermTerminalStartup.script("printf ready").prepare(
        cliPath: nil,
        shellPath: shellURL.path,
        temporaryDirectory: fixture.rootURL
      )
      let directoryURL = prepared.cleanupDirectoryURL
      let scriptURL = directoryURL.appendingPathComponent(fileName)
      if name == "elvish" {
        #expect(prepared.initialInput == "\(command) <\(scriptURL.path))\n")
      } else {
        #expect(prepared.initialInput == "\(command) \(scriptURL.path)\n")
      }
      prepared.cleanupToken.cleanup()
    }
  }

  @Test
  func scriptStartupRejectsNul() throws {
    let fixture = try StartupTransportFixture()
    defer { fixture.remove() }
    #expect(throws: SupatermTerminalStartupError.self) {
      try SupatermTerminalStartup.script("printf ready\0ignored").prepare(
        cliPath: nil,
        shellPath: "/bin/zsh",
        temporaryDirectory: fixture.rootURL
      )
    }
  }

  @Test
  func nushellSourcesStartupScriptWhenAvailable() throws {
    let shellURL = ["/opt/homebrew/bin/nu", "/usr/local/bin/nu"]
      .map { URL(fileURLWithPath: $0) }
      .first { FileManager.default.isExecutableFile(atPath: $0.path) }
    guard let shellURL else { return }
    let fixture = try StartupTransportFixture()
    defer { fixture.remove() }
    let outputURL = fixture.rootURL.appendingPathComponent("nu-output")
    let prepared = try SupatermTerminalStartup.script(
      "/usr/bin/printf ready o> \(outputURL.path)"
    ).prepare(
      cliPath: nil,
      shellPath: shellURL.path,
      temporaryDirectory: fixture.rootURL
    )
    defer { prepared.cleanupToken.cleanup() }
    let transportDirectoryURL = prepared.cleanupDirectoryURL
    let process = Process()
    process.executableURL = shellURL
    process.arguments = ["-c", prepared.initialInput]
    try process.run()
    process.waitUntilExit()

    #expect(process.terminationStatus == 0)
    #expect(try String(contentsOf: outputURL, encoding: .utf8) == "ready")
    #expect(!FileManager.default.fileExists(atPath: transportDirectoryURL.path))
  }

  @Test
  func codableRoundTripsBothStartupKinds() throws {
    let values: [SupatermTerminalStartup] = [
      .arguments(["", "two words", "line one\nline two", "雪"]),
      .script("printf '%s\\n' ready\n"),
    ]

    for value in values {
      let data = try JSONEncoder().encode(value)
      let decoded = try JSONDecoder().decode(SupatermTerminalStartup.self, from: data)

      expectNoDifference(decoded, value)
    }
  }
}

private struct StartupTransportFixture {
  let rootURL: URL
  let cliURL: URL

  init() throws {
    rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "supaterm-startup-tests-\(UUID().uuidString.lowercased())",
      isDirectory: true
    )
    cliURL = rootURL.appendingPathComponent("sp", isDirectory: false)
    try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: false)
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: cliURL, options: .withoutOverwriting)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700],
      ofItemAtPath: cliURL.path
    )
  }

  func remove() {
    try? FileManager.default.removeItem(at: rootURL)
  }

  func executable(named name: String) throws -> URL {
    let url = rootURL.appendingPathComponent(name, isDirectory: false)
    try Data("#!/bin/sh\nexit 0\n".utf8).write(to: url, options: .withoutOverwriting)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o700],
      ofItemAtPath: url.path
    )
    return url
  }
}

private func permissions(of url: URL) throws -> Int {
  let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
  return try #require(attributes[.posixPermissions] as? Int)
}
