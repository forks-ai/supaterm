import CustomDump
import Foundation
import Testing

@testable import SupatermCLIShared

struct SupatermTerminalStartupTests {
  @Test
  func execPreservesExactArgumentsAndSearchPath() {
    let startup = SupatermTerminalStartup.exec(
      [
        "tool",
        "",
        "two words",
        "line one\nline two",
        "'\"$`\\;|&<>(){}[]*?!#~",
        "unicode-👩🏽‍💻-東京",
      ],
      searchPath: "/opt/homebrew/bin:/usr/bin:/bin"
    )

    #expect(startup.isValid)
  }

  @Test
  func execRejectsInvalidArgumentsAndSearchPath() {
    for startup in [
      SupatermTerminalStartup.exec([], searchPath: "/usr/bin:/bin"),
      .exec([""], searchPath: "/usr/bin:/bin"),
      .exec([" \n "], searchPath: "/usr/bin:/bin"),
      .exec(["tool", "nul\0byte"], searchPath: "/usr/bin:/bin"),
      .exec(["tool"], searchPath: "/usr/bin\0/bin"),
      .exec(["tool"] + Array(repeating: "", count: 4_096), searchPath: "/usr/bin:/bin"),
      .exec(
        ["tool", String(repeating: "x", count: 8 * 1_024 * 1_024)],
        searchPath: "/usr/bin:/bin"
      ),
      .exec(["tool"], searchPath: String(repeating: "x", count: 8 * 1_024 * 1_024 + 1)),
      .exec(
        ["tool", String(repeating: "x", count: 4 * 1_024 * 1_024)],
        searchPath: String(repeating: "y", count: 4 * 1_024 * 1_024)
      ),
    ] {
      #expect(!startup.isValid)
    }
  }

  @Test
  func shellAcceptsText() {
    let startup = SupatermTerminalStartup.shell("printf '%s\\n' ready\n")

    #expect(startup.isValid)
    #expect(!SupatermTerminalStartup.shell("").isValid)
    #expect(!SupatermTerminalStartup.shell("printf ready\0ignored").isValid)
    #expect(
      !SupatermTerminalStartup.shell(
        String(repeating: "x", count: 8 * 1_024 * 1_024 + 1)
      ).isValid
    )
  }

  @Test
  func codableRoundTripsBothStartupKinds() throws {
    let values: [SupatermTerminalStartup] = [
      .exec(
        ["tool", "", "two words", "line one\nline two", "雪"],
        searchPath: "/custom/bin:/usr/bin"
      ),
      .exec(["/usr/bin/true"], searchPath: ""),
      .shell("printf '%s\\n' ready\n"),
    ]

    for value in values {
      let data = try JSONEncoder().encode(value)
      let decoded = try JSONDecoder().decode(SupatermTerminalStartup.self, from: data)

      expectNoDifference(decoded, value)
    }
  }
}
