import ArgumentParser
import Foundation
import SupatermCLIShared

extension SP {
  struct Skills: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "skills",
      abstract: "List, retrieve, locate, and install Supaterm skills.",
      discussion: SPHelp.skillsDiscussion,
      subcommands: [ListSkills.self, GetSkill.self, PathSkill.self, InstallSkill.self],
      defaultSubcommand: ListSkills.self
    )
  }

  struct ListSkills: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "list",
      abstract: "List bundled Supaterm skills.",
      discussion: SPHelp.listSkillsDiscussion
    )

    @Flag(name: .long, help: "Print command output as JSON.")
    var json = false

    @OptionGroup
    var connection: SPConnectionOptions

    mutating func run() throws {
      let skills = try runSkillsOperation(json: json) {
        try sendSkillsRequest(
          .skillsList(),
          connection: connection,
          as: SupatermSkillListResult.self
        ).skills
      }
      if json {
        print(try jsonString(SPSkillsSuccess(data: skills)))
      } else {
        for skill in skills {
          print("\(skill.name)\t\(skill.description)")
        }
      }
    }
  }

  struct GetSkill: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "get",
      abstract: "Print a bundled Supaterm skill.",
      discussion: SPHelp.getSkillDiscussion
    )

    @Argument(help: "Bundled skill name.")
    var name: String

    @Flag(name: .long, help: "Include every bundled file for the skill.")
    var full = false

    @OptionGroup
    var connection: SPConnectionOptions

    mutating func run() throws {
      let skill = try sendSkillsRequest(
        try .skillsGet(SupatermSkillGetRequest(name: name, full: full)),
        connection: connection,
        as: SupatermSkillContent.self
      )
      let output = renderSkill(skill)
      print(output, terminator: output.hasSuffix("\n") ? "" : "\n")
    }
  }

  struct PathSkill: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "path",
      abstract: "Print a bundled Supaterm skill directory.",
      discussion: SPHelp.pathSkillDiscussion
    )

    @Argument(help: "Bundled skill name.")
    var name: String

    @OptionGroup
    var connection: SPConnectionOptions

    mutating func run() throws {
      print(
        try sendSkillsRequest(
          try .skillsPath(SupatermSkillPathRequest(name: name)),
          connection: connection,
          as: SupatermSkillPathResult.self
        ).path
      )
    }
  }

  struct InstallSkill: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "install",
      abstract: "Install Supaterm's discovery skill.",
      discussion: SPHelp.installSkillDiscussion
    )

    @Flag(name: .long, help: "Print command output as JSON.")
    var json = false

    @OptionGroup
    var connection: SPConnectionOptions

    mutating func run() throws {
      let result = try runSkillsOperation(json: json) {
        try sendSkillsRequest(
          .skillsInstall(),
          connection: connection,
          as: SupatermSkillInstallResult.self
        )
      }
      if json {
        print(try jsonString(SPSkillsSuccess(data: [result])))
      } else {
        print(result.path)
      }
    }
  }
}

struct SPSkillsSuccess<Data: Encodable>: Encodable {
  let success = true
  let data: Data
}

struct SPSkillsFailure: Encodable {
  let error: String
  let success = false
}

private struct SPSkillsError: LocalizedError {
  let message: String

  var errorDescription: String? {
    message
  }
}

private func sendSkillsRequest<Result: Decodable>(
  _ request: SupatermSocketRequest,
  connection: SPConnectionOptions,
  as resultType: Result.Type
) throws -> Result {
  let client: SPSocketClient
  do {
    client = try socketClient(
      path: connection.explicitSocketPath,
      instance: connection.instance
    )
  } catch let error as ValidationError {
    throw SPSkillsError(message: error.message)
  }
  let response = try client.send(request)
  guard response.ok else {
    throw SPSkillsError(message: response.error?.message ?? "Supaterm socket request failed.")
  }
  return try response.decodeResult(resultType)
}

func runSkillsOperation<Result>(json: Bool, operation: () throws -> Result) throws -> Result {
  do {
    return try operation()
  } catch {
    guard json else {
      throw error
    }
    print(try jsonString(SPSkillsFailure(error: error.localizedDescription)))
    throw ExitCode.failure
  }
}

func renderSkill(_ skill: SupatermSkillContent) -> String {
  var output = skill.content
  for file in skill.files ?? [] {
    if !output.hasSuffix("\n") {
      output += "\n"
    }
    output += "\n--- \(file.path) ---\n\n"
    output += file.content
  }
  return output
}
