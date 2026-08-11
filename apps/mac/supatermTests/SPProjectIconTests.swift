import ArgumentParser
import Foundation
import Testing

@testable import SPCLI

struct SPProjectIconTests {
  @Test
  func resolvesWellKnownIconsInOrder() throws {
    let fixture = try SPProjectIconFixture()
    defer { fixture.remove() }
    let expectedURL = try fixture.write("public/favicon.svg")
    _ = try fixture.write("assets/logo.svg")

    #expect(SPProjectIconResolver.resolve(in: fixture.rootURL) == expectedURL)
  }

  @Test
  func resolvesHTMLIconMetadataFromPublic() throws {
    let fixture = try SPProjectIconFixture()
    defer { fixture.remove() }
    try fixture.writeText("index.html", #"<link href="/brand/logo.svg?v=1" rel="icon">"#)
    let expectedURL = try fixture.write("public/brand/logo.svg")

    #expect(SPProjectIconResolver.resolve(in: fixture.rootURL) == expectedURL)
  }

  @Test
  func resolvesRouteIconMetadataWithEitherFieldOrder() throws {
    let fixture = try SPProjectIconFixture()
    defer { fixture.remove() }
    try fixture.writeText(
      "src/routes/__root.tsx",
      #"const links = [{ href: "/brand/logo.png", rel: "shortcut icon" }];"#
    )
    let expectedURL = try fixture.write("public/brand/logo.png")

    #expect(SPProjectIconResolver.resolve(in: fixture.rootURL) == expectedURL)
  }

  @Test
  func rejectsIconsOutsideTheProject() throws {
    let fixture = try SPProjectIconFixture()
    defer { fixture.remove() }
    let outsideURL = fixture.rootURL
      .deletingLastPathComponent()
      .appendingPathComponent("\(UUID().uuidString).svg", isDirectory: false)
    defer { try? FileManager.default.removeItem(at: outsideURL) }
    try Data("outside".utf8).write(to: outsideURL)
    let iconURL = fixture.rootURL.appendingPathComponent("assets/logo.svg", isDirectory: false)
    try FileManager.default.createDirectory(
      at: iconURL.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try FileManager.default.createSymbolicLink(at: iconURL, withDestinationURL: outsideURL)

    #expect(SPProjectIconResolver.resolve(in: fixture.rootURL) == nil)
  }

  @Test
  func rejectsNonImageIconMetadata() throws {
    let fixture = try SPProjectIconFixture()
    defer { fixture.remove() }
    try fixture.writeText("index.html", #"<link rel="icon" href="/secret.txt">"#)
    try fixture.writeText("public/secret.txt", "secret")

    #expect(SPProjectIconResolver.resolve(in: fixture.rootURL) == nil)
  }

  @Test
  func commandParsesDefaultPathAndJSONOutput() throws {
    let defaultCommand = try #require(
      try SP.parseAsRoot(["project", "icon"]) as? SP.ProjectIcon
    )
    let explicitCommand = try #require(
      try SP.parseAsRoot(["project", "icon", "~/code/project", "--json"])
        as? SP.ProjectIcon
    )

    #expect(defaultCommand.path == nil)
    #expect(explicitCommand.path == "~/code/project")
    #expect(explicitCommand.output.json)
  }

  @Test
  func missingIconJSONIncludesNullPath() throws {
    #expect(try jsonString(SPProjectIconResult(path: nil)) == #"{"path":null}"#)
  }
}

private struct SPProjectIconFixture {
  let rootURL: URL

  init() throws {
    rootURL = FileManager.default.temporaryDirectory.appendingPathComponent(
      "supaterm-project-icon-\(UUID().uuidString)",
      isDirectory: true
    )
    try FileManager.default.createDirectory(at: rootURL, withIntermediateDirectories: false)
  }

  func write(_ relativePath: String) throws -> URL {
    let url = rootURL.appendingPathComponent(relativePath, isDirectory: false)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data(relativePath.utf8).write(to: url)
    return url.standardizedFileURL.resolvingSymlinksInPath()
  }

  func writeText(_ relativePath: String, _ text: String) throws {
    let url = rootURL.appendingPathComponent(relativePath, isDirectory: false)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try Data(text.utf8).write(to: url)
  }

  func remove() {
    try? FileManager.default.removeItem(at: rootURL)
  }
}
