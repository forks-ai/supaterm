import Foundation
import SupatermCLIShared
import Testing

@testable import SPCLI

struct SPSkillsCommandTests {
  @Test
  func listPrintsTabSeparatedRowsAndJSONFromTheAppCatalog() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let log = SPSocketRequestLog()
    let result = SupatermSkillListResult(
      skills: [
        SupatermSkillSummary(name: "coding-agents", description: "Launch coding agents."),
        SupatermSkillSummary(name: "core", description: "Control Supaterm."),
      ]
    )

    try await withSocketRuntime(
      replying: { request, _ in
        log.record(request)
        return try .ok(id: request.id, encodableResult: result)
      },
      run: { endpoint in
        let socket = ["--socket", endpoint.path]
        let list = try cli.run(["skills", "list"] + socket)
        let json = try cli.run(["skills", "list", "--json"] + socket)
        let defaultSubcommand = try cli.run(["skills"] + socket)

        #expect(
          list
            == SPCLIResult(
              exitCode: 0,
              stdout: """
                coding-agents\tLaunch coding agents.
                core\tControl Supaterm.

                """,
              stderr: ""
            )
        )
        #expect(defaultSubcommand == list)
        #expect(
          json.stdout == """
            {"data":[{"description":"Launch coding agents.","name":"coding-agents"},\
            {"description":"Control Supaterm.","name":"core"}],"success":true}

            """
        )
      }
    )

    #expect(log.requests.map(\.method) == Array(repeating: SupatermSocketMethod.appSkillsList, count: 3))
  }

  @Test
  func getPrintsSkillContentAndAppendsBundledFilesWithFull() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let log = SPSocketRequestLog()

    try await withSocketRuntime(
      replying: { request, _ in
        log.record(request)
        let payload = try request.decodeParams(SupatermSkillGetRequest.self)
        return try .ok(
          id: request.id,
          encodableResult: SupatermSkillContent(
            name: payload.name,
            content: "# Supaterm core\n",
            files: payload.full
              ? [SupatermSkillFile(path: "references/pane.md", content: "Panes\n")]
              : nil
          )
        )
      },
      run: { endpoint in
        let socket = ["--socket", endpoint.path]
        let core = try cli.run(["skills", "get", "core"] + socket)
        let full = try cli.run(["skills", "get", "core", "--full"] + socket)

        #expect(core == SPCLIResult(exitCode: 0, stdout: "# Supaterm core\n", stderr: ""))
        #expect(
          full.stdout == """
            # Supaterm core

            --- references/pane.md ---

            Panes

            """
        )
      }
    )

    #expect(log.requests.map(\.method) == Array(repeating: SupatermSocketMethod.appSkillsGet, count: 2))
    #expect(
      try log.requests.map { try jsonString($0.params) } == [
        #"{"full":false,"name":"core"}"#,
        #"{"full":true,"name":"core"}"#,
      ]
    )
  }

  @Test
  func pathPrintsTheBundledSkillDirectory() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let log = SPSocketRequestLog()

    try await withSocketRuntime(
      replying: { request, _ in
        log.record(request)
        return try .ok(
          id: request.id,
          encodableResult: SupatermSkillPathResult(path: "/Applications/supaterm.app/skill-data/core")
        )
      },
      run: { endpoint in
        let path = try cli.run(["skills", "path", "core", "--socket", endpoint.path])

        #expect(
          path
            == SPCLIResult(
              exitCode: 0,
              stdout: "/Applications/supaterm.app/skill-data/core\n",
              stderr: ""
            )
        )
      }
    )

    #expect(log.requests.map(\.method) == [SupatermSocketMethod.appSkillsPath])
    #expect(try log.requests.map { try jsonString($0.params) } == [#"{"name":"core"}"#])
  }

  @Test
  func installPrintsTheInstalledSkillDirectoryAndJSON() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }
    let log = SPSocketRequestLog()
    let installedPath = "/Users/test/.agents/skills/supaterm"

    try await withSocketRuntime(
      replying: { request, _ in
        log.record(request)
        return try .ok(
          id: request.id,
          encodableResult: SupatermSkillInstallResult(path: installedPath)
        )
      },
      run: { endpoint in
        let socket = ["--socket", endpoint.path]
        let install = try cli.run(["skills", "install"] + socket)
        let json = try cli.run(["skills", "install", "--json"] + socket)

        #expect(install == SPCLIResult(exitCode: 0, stdout: installedPath + "\n", stderr: ""))
        #expect(
          json.stdout == """
            {"data":[{"path":"\\/Users\\/test\\/.agents\\/skills\\/supaterm"}],"success":true}

            """
        )
      }
    )

    #expect(log.requests.map(\.method) == Array(repeating: SupatermSocketMethod.appSkillsInstall, count: 2))
  }

  @Test
  func missingSkillsFailWithTheServerMessage() async throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    try await withSocketRuntime(
      replying: { request, _ in
        .error(
          id: request.id,
          code: "not_found",
          message: "Skill not found: missing. Run `sp skills list` to see available skills."
        )
      },
      run: { endpoint in
        let socket = ["--socket", endpoint.path]
        for arguments in [["skills", "get", "missing"], ["skills", "path", "missing"]] {
          let result = try cli.run(arguments + socket)

          #expect(result.exitCode == 1)
          #expect(result.stdout.isEmpty)
          #expect(
            result.stderr
              == "Error: Skill not found: missing. Run `sp skills list` to see available skills.\n"
          )
        }

        let json = try cli.run(["skills", "list", "--json"] + socket)
        #expect(json.exitCode == 1)
        #expect(
          json.stdout == """
            {"error":"Skill not found: missing. Run `sp skills list` to see available skills.",\
            "success":false}

            """
        )
      }
    )
  }

  @Test(
    arguments: [
      ["skills", "list"],
      ["skills", "get", "core"],
      ["skills", "path", "core"],
      ["skills", "install"],
    ]
  )
  func skillCommandsFailWithoutAReachableInstance(arguments: [String]) throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let result = try cli.run(arguments)

    #expect(result.exitCode == 1)
    #expect(result.stdout.isEmpty)
    #expect(result.stderr == "Error: No reachable Supaterm instance was found.\n")
  }

  @Test
  func listReportsUnreachableInstancesInsideTheJSONEnvelope() throws {
    let cli = try SPCLIHarness()
    defer { cli.remove() }

    let result = try cli.run(["skills", "list", "--json"])

    #expect(result.exitCode == 1)
    #expect(
      result.stdout == """
        {"error":"No reachable Supaterm instance was found.","success":false}

        """
    )
  }
}
