import ArgumentParser
import Foundation
import SupatermCLIShared

struct SPProjectIconResult: Encodable, Equatable {
  let path: String?

  private enum CodingKeys: String, CodingKey {
    case path
  }

  func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    if let path {
      try container.encode(path, forKey: .path)
    } else {
      try container.encodeNil(forKey: .path)
    }
  }
}

extension SP {
  struct Project: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "project",
      abstract: "Inspect project metadata.",
      discussion: SPHelp.projectDiscussion,
      subcommands: [ProjectIcon.self]
    )

    mutating func run() throws {
      print(Self.helpMessage())
    }
  }

  struct ProjectIcon: ParsableCommand {
    static let configuration = CommandConfiguration(
      commandName: "icon",
      abstract: "Find the first project icon.",
      discussion: SPHelp.projectIconDiscussion
    )

    @Argument(help: "Project directory. Defaults to the current directory.")
    var path: String?

    @OptionGroup
    var output: SPOutputOptions

    mutating func run() throws {
      applyOutputStyle(output)
      let projectURL = try resolvedProjectURL(path)
      let result = SPProjectIconResult(
        path: SupatermProjectIconResolver.resolve(in: projectURL)?.path
      )
      if result.path == nil, output.mode == .plain {
        return
      }
      try emitCommandResult(
        result,
        options: output,
        plain: result.path ?? "",
        human: result.path ?? "No project icon found."
      )
    }

    private func resolvedProjectURL(_ path: String?) throws -> URL {
      let rawPath = path ?? FileManager.default.currentDirectoryPath
      let trimmedPath = rawPath.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !trimmedPath.isEmpty else {
        throw ValidationError("Project directory must not be empty.")
      }

      let expandedPath = expandCLIHomePath(trimmedPath)
      let projectURL =
        NSString(string: expandedPath).isAbsolutePath
        ? URL(fileURLWithPath: expandedPath, isDirectory: true)
        : URL(fileURLWithPath: FileManager.default.currentDirectoryPath, isDirectory: true)
          .appendingPathComponent(expandedPath, isDirectory: true)
      let resolvedURL = projectURL.standardizedFileURL.resolvingSymlinksInPath()
      var isDirectory = ObjCBool(false)
      guard
        FileManager.default.fileExists(atPath: resolvedURL.path, isDirectory: &isDirectory),
        isDirectory.boolValue
      else {
        throw ValidationError("Project directory does not exist: \(resolvedURL.path)")
      }
      return resolvedURL
    }
  }
}
