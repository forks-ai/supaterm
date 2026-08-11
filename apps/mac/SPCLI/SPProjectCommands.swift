import ArgumentParser
import Foundation

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

enum SPProjectIconResolver {
  private static let candidates = [
    "favicon.svg",
    "favicon.ico",
    "favicon.png",
    "public/favicon.svg",
    "public/favicon.ico",
    "public/favicon.png",
    "app/favicon.ico",
    "app/favicon.png",
    "app/icon.svg",
    "app/icon.png",
    "app/icon.ico",
    "src/favicon.ico",
    "src/favicon.svg",
    "src/app/favicon.ico",
    "src/app/icon.svg",
    "src/app/icon.png",
    "assets/icon.svg",
    "assets/icon.png",
    "assets/logo.svg",
    "assets/logo.png",
    ".idea/icon.svg",
  ]

  private static let sourceFiles = [
    "index.html",
    "public/index.html",
    "app/routes/__root.tsx",
    "src/routes/__root.tsx",
    "app/root.tsx",
    "src/root.tsx",
    "src/index.html",
  ]

  private static let imageExtensions = Set([
    "avif",
    "gif",
    "ico",
    "jpeg",
    "jpg",
    "png",
    "svg",
    "webp",
  ])

  static func resolve(in directoryURL: URL) -> URL? {
    let rootURL = directoryURL.standardizedFileURL.resolvingSymlinksInPath()
    var isDirectory = ObjCBool(false)
    guard
      FileManager.default.fileExists(atPath: rootURL.path, isDirectory: &isDirectory),
      isDirectory.boolValue
    else {
      return nil
    }

    for candidate in candidates {
      if let iconURL = existingIcon(relativePath: candidate, rootURL: rootURL) {
        return iconURL
      }
    }

    for sourceFile in sourceFiles {
      guard
        let sourceURL = existingFile(relativePath: sourceFile, rootURL: rootURL),
        let source = try? String(contentsOf: sourceURL, encoding: .utf8),
        let href = iconHref(in: source)
      else {
        continue
      }

      let cleanHref = href.hasPrefix("/") ? String(href.dropFirst()) : href
      for candidate in ["public/\(cleanHref)", cleanHref] {
        if let iconURL = existingIcon(relativePath: candidate, rootURL: rootURL) {
          return iconURL
        }
      }
    }

    return nil
  }

  private static func existingIcon(relativePath: String, rootURL: URL) -> URL? {
    guard let url = existingFile(relativePath: relativePath, rootURL: rootURL) else {
      return nil
    }
    return imageExtensions.contains(url.pathExtension.lowercased()) ? url : nil
  }

  private static func existingFile(relativePath: String, rootURL: URL) -> URL? {
    let path = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !path.isEmpty, !NSString(string: path).isAbsolutePath else {
      return nil
    }

    let fileURL =
      rootURL
      .appendingPathComponent(path, isDirectory: false)
      .standardizedFileURL
      .resolvingSymlinksInPath()
    let rootComponents = rootURL.pathComponents
    let fileComponents = fileURL.pathComponents
    guard
      fileComponents.count > rootComponents.count,
      Array(fileComponents.prefix(rootComponents.count)) == rootComponents
    else {
      return nil
    }

    guard
      (try? fileURL.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
    else {
      return nil
    }
    return fileURL
  }

  private static func iconHref(in source: String) -> String? {
    if let href = firstCapture(
      pattern:
        #"<link\b(?=[^>]*\brel=["'](?:icon|shortcut icon)["'])(?=[^>]*\bhref=["']([^"'?]+))[^>]*>"#,
      source: source
    ) {
      return href
    }

    for run in source.split(separator: "}", omittingEmptySubsequences: false) {
      let value = String(run)
      guard
        contains(pattern: #"\brel\s*:\s*["'](?:icon|shortcut icon)["']"#, source: value),
        let href = firstCapture(pattern: #"\bhref\s*:\s*["']([^"'?]+)"#, source: value)
      else {
        continue
      }
      return href
    }

    return nil
  }

  private static func firstCapture(pattern: String, source: String) -> String? {
    guard
      let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
      let match = expression.firstMatch(
        in: source,
        range: NSRange(source.startIndex..., in: source)
      ),
      match.numberOfRanges > 1,
      let range = Range(match.range(at: 1), in: source)
    else {
      return nil
    }
    return String(source[range])
  }

  private static func contains(pattern: String, source: String) -> Bool {
    guard let expression = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive)
    else {
      return false
    }
    return expression.firstMatch(
      in: source,
      range: NSRange(source.startIndex..., in: source)
    ) != nil
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
      let result = SPProjectIconResult(path: SPProjectIconResolver.resolve(in: projectURL)?.path)
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
