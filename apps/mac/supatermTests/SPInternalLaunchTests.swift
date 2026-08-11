import Foundation
import Testing

@testable import SPCLI
@testable import SupatermCLIShared

struct SPInternalLaunchTests {
  @Test
  func consumesPrivatePayloadWithoutChangingArguments() throws {
    let rootURL = try temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootURL) }
    let expected = ["tool", "", "two words", "line one\nline two", "bang!", "雪"]
    let prepared = try SupatermTerminalStartup.arguments(expected).prepare(
      cliPath: "/usr/bin/true",
      temporaryDirectory: rootURL
    )
    defer { prepared.cleanupToken.cleanup() }
    let payloadURL = payloadURL(prepared)

    #expect(try SP.Launch.arguments(payloadPath: payloadURL.path) == expected)
    #expect(!FileManager.default.fileExists(atPath: payloadURL.path))
    #expect(throws: Error.self) {
      try SP.Launch.arguments(payloadPath: payloadURL.path)
    }
  }

  @Test
  func consumesPayloadFromProductionTemporaryDirectory() throws {
    let expected = ["tool", "secret"]
    let prepared = try SupatermTerminalStartup.arguments(expected).prepare(
      cliPath: "/usr/bin/true"
    )
    defer { prepared.cleanupToken.cleanup() }

    #expect(try SP.Launch.arguments(payloadPath: payloadURL(prepared).path) == expected)
  }

  @Test
  func rejectsPayloadWithLoosePermissions() throws {
    let rootURL = try temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootURL) }
    let prepared = try SupatermTerminalStartup.arguments(["tool"]).prepare(
      cliPath: "/usr/bin/true",
      temporaryDirectory: rootURL
    )
    defer { prepared.cleanupToken.cleanup() }
    let payloadURL = payloadURL(prepared)
    try FileManager.default.setAttributes(
      [.posixPermissions: 0o644],
      ofItemAtPath: payloadURL.path
    )

    do {
      _ = try SP.Launch.arguments(payloadPath: payloadURL.path)
      Issue.record("Expected loose payload permissions to fail.")
    } catch {
      #expect(FileManager.default.fileExists(atPath: payloadURL.path))
    }
  }

  @Test
  func rejectsOversizedPayload() throws {
    let rootURL = try temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootURL) }
    let prepared = try SupatermTerminalStartup.arguments(["tool"]).prepare(
      cliPath: "/usr/bin/true",
      temporaryDirectory: rootURL
    )
    defer { prepared.cleanupToken.cleanup() }
    let payloadURL = payloadURL(prepared)
    try Data(
      repeating: 0,
      count: SupatermTerminalStartup.maximumArgumentsPayloadSize + 1
    ).write(to: payloadURL)

    #expect(throws: Error.self) {
      try SP.Launch.arguments(payloadPath: payloadURL.path)
    }
    #expect(FileManager.default.fileExists(atPath: payloadURL.path))
  }

  @Test
  func payloadCanBeConsumedOnlyOnce() async throws {
    let rootURL = try temporaryRoot()
    defer { try? FileManager.default.removeItem(at: rootURL) }
    let expected = ["tool", "secret"]
    let prepared = try SupatermTerminalStartup.arguments(expected).prepare(
      cliPath: "/usr/bin/true",
      temporaryDirectory: rootURL
    )
    defer { prepared.cleanupToken.cleanup() }
    let payloadURL = payloadURL(prepared)
    try FileManager.default.removeItem(
      at: payloadURL.deletingLastPathComponent().appendingPathComponent("launch")
    )

    let results = await withTaskGroup(of: [String]?.self) { group in
      for _ in 0..<2 {
        group.addTask {
          try? SP.Launch.arguments(payloadPath: payloadURL.path)
        }
      }
      var values: [[String]?] = []
      for await value in group {
        values.append(value)
      }
      return values
    }

    #expect(results.compactMap { $0 } == [expected])
    #expect(!FileManager.default.fileExists(atPath: payloadURL.deletingLastPathComponent().path))
  }

  @Test
  func launcherPreservesBareArgumentZero() throws {
    let harness = try SPCLIHarness()
    defer { harness.remove() }
    let outputURL = harness.rootURL.appendingPathComponent("argv-zero")
    let prepared = try SupatermTerminalStartup.arguments([
      "sh",
      "-c",
      "/usr/bin/printf '%s' \"$0\" > \"$1\"",
      "sh",
      outputURL.path,
    ]).prepare(
      cliPath: "/usr/bin/true",
      temporaryDirectory: harness.rootURL
    )
    defer { prepared.cleanupToken.cleanup() }

    let result = try harness.run(["internal", "launch", payloadURL(prepared).path])

    #expect(result.exitCode == 0)
    #expect(try String(contentsOf: outputURL, encoding: .utf8) == "sh")
  }

  @Test
  func validationRejectsEmptyWhitespaceAndNulArguments() {
    #expect(!SupatermTerminalStartup.validArguments([]))
    #expect(!SupatermTerminalStartup.validArguments([""]))
    #expect(!SupatermTerminalStartup.validArguments([" \n "]))
    #expect(!SupatermTerminalStartup.validArguments(["tool", "nul\0byte"]))
    #expect(SupatermTerminalStartup.validArguments(["tool", "", "two words"]))
  }
}

private func temporaryRoot() throws -> URL {
  let url = FileManager.default.temporaryDirectory.appendingPathComponent(
    "supaterm-internal-launch-tests-\(UUID().uuidString.lowercased())",
    isDirectory: true
  )
  try FileManager.default.createDirectory(at: url, withIntermediateDirectories: false)
  return url
}

private func payloadURL(_ prepared: SupatermPreparedTerminalStartup) -> URL {
  URL(
    fileURLWithPath: prepared.initialInput.trimmingCharacters(in: .whitespacesAndNewlines)
  )
  .deletingLastPathComponent()
  .appendingPathComponent("arguments.json")
}
