import Foundation
import SupatermCLIShared
import Testing

struct SPSkillsCommandTests {
  @Test
  func listPrintsBundledSkillsAsTabSeparatedRowsAndJSON() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let list = try cli.run(["skills", "list"])
    let json = try cli.run(["skills", "list", "--json"])
    let defaultSubcommand = try cli.run(["skills"])

    #expect(list.exitCode == 0)
    #expect(
      list.stdout.split(separator: "\n").map { $0.split(separator: "\t").first ?? "" } == ["coding-agents", "core"])
    #expect(defaultSubcommand == list)

    let response = try decodedCLIJSON(SPSkillsResponse<SupatermSkillSummary>.self, from: json)
    #expect(response.success)
    #expect(response.data.map(\.name) == ["coding-agents", "core"])
    #expect(response.data.allSatisfy { !$0.description.isEmpty })
  }

  @Test
  func getPrintsSkillContentAndOptionallyEveryBundledFile() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let core = try cli.run(["skills", "get", "core"])
    let full = try cli.run(["skills", "get", "core", "--full"])

    #expect(core.exitCode == 0)
    #expect(core.stdout.hasSuffix("\n"))
    #expect(!core.stdout.contains("--- references/"))
    #expect(full.stdout.hasPrefix(core.stdout.trimmingCharacters(in: .newlines)))
    #expect(full.stdout.contains("--- references/pane.md ---"))
  }

  @Test
  func pathPrintsTheBundledSkillDirectory() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let path = try cli.run(["skills", "path", "core"])
    let directory = path.stdout.trimmingCharacters(in: .newlines)

    #expect(path.exitCode == 0)
    #expect(directory.hasSuffix("/skill-data/core"))
    #expect(FileManager.default.fileExists(atPath: directory + "/SKILL.md"))
  }

  @Test
  func missingSkillsFailWithoutJSONOutput() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let missing = try cli.run(["skills", "get", "missing"])
    let missingPath = try cli.run(["skills", "path", "missing"])

    for result in [missing, missingPath] {
      #expect(result.exitCode == 1)
      #expect(result.stdout.isEmpty)
      #expect(
        result.stderr
          == "Error: Skill not found: missing. Run `sp skills list` to see available skills.\n"
      )
    }
  }

  @Test
  func installCopiesTheDiscoverySkillIntoTheCLIHome() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let skillDirectoryURL = SupatermSkills.skillDirectoryURL(homeDirectoryURL: cli.homeURL)

    let install = try cli.run(["skills", "install"])

    #expect(install.exitCode == 0)
    #expect(install.stdout == skillDirectoryURL.path + "\n")
    #expect(
      FileManager.default.fileExists(
        atPath: SupatermSkills.skillDefinitionURL(skillDirectoryURL: skillDirectoryURL).path
      )
    )

    let reinstall = try cli.run(["skills", "install", "--json"])
    let response = try decodedCLIJSON(SPSkillsResponse<SupatermSkillInstallResult>.self, from: reinstall)
    #expect(response.success)
    #expect(response.data.map(\.path) == [skillDirectoryURL.path])
  }
}

struct SPSkillsResponse<Value: Decodable>: Decodable {
  let success: Bool
  let data: [Value]
}
