import Foundation
import SupatermCLIShared

nonisolated enum ClaudeSubagentMetadataParser {
  struct Metadata: Equatable {
    let nickname: String?
    let task: String?
    let transcriptPath: String
    let usage: TerminalAgentChildUsage?
  }

  static func metadata(
    transcriptPath: String?,
    agentID: String?
  ) -> Metadata? {
    guard let agentID,
      let metadataURL = metadataURL(transcriptPath: transcriptPath, agentID: agentID),
      let data = try? Data(contentsOf: metadataURL),
      let object = (try? JSONDecoder().decode(JSONValue.self, from: data))?.objectValue
    else {
      return nil
    }
    let childTranscript =
      metadataURL
      .deletingLastPathComponent()
      .appendingPathComponent("agent-\(agentID).jsonl")
    let reading = ClaudeSubagentTranscriptReader.read(at: childTranscript)
    let nickname =
      AgentProgressParsing.normalizedTitle(object["name"]?.stringValue)
      ?? workflowName(besides: metadataURL)
    let task =
      AgentProgressParsing.normalizedTitle(object["description"]?.stringValue)
      ?? spawnPromptTask(reading?.spawnPrompt, besides: childTranscript)
    return Metadata(
      nickname: nickname,
      task: task,
      transcriptPath: childTranscript.path,
      usage: reading?.usage
    )
  }

  private static let maxPromptTaskLength = 140

  private static func metadataURL(
    transcriptPath: String?,
    agentID: String
  ) -> URL? {
    guard let transcriptPath else { return nil }
    let transcript = URL(fileURLWithPath: transcriptPath)
    guard transcript.pathExtension == "jsonl" else { return nil }
    let subagents =
      transcript
      .deletingPathExtension()
      .appendingPathComponent("subagents")
    let fileName = "agent-\(agentID).meta.json"
    let direct = subagents.appendingPathComponent(fileName)
    if FileManager.default.fileExists(atPath: direct.path) {
      return direct
    }
    let workflows = subagents.appendingPathComponent("workflows")
    return
      contents(of: workflows)
      .map {
        workflows.appendingPathComponent($0.lastPathComponent).appendingPathComponent(fileName)
      }
      .first { FileManager.default.fileExists(atPath: $0.path) }
  }

  private static func workflowName(besides metadataURL: URL) -> String? {
    guard let runDirectory = workflowRunDirectory(containing: metadataURL) else { return nil }
    let suffix = "-\(runDirectory.lastPathComponent).js"
    let scriptsDirectory =
      runDirectory
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("workflows")
      .appendingPathComponent("scripts")
    guard
      let script =
        contents(of: scriptsDirectory)
        .map(\.lastPathComponent)
        .first(where: { $0.hasSuffix(suffix) })
    else {
      return nil
    }
    return AgentProgressParsing.normalizedTitle(String(script.dropLast(suffix.count)))
  }

  private static func spawnPromptTask(
    _ prompt: String?,
    besides transcript: URL
  ) -> String? {
    guard let prompt else { return nil }
    let title = distinguishingLine(of: prompt, besides: transcript) ?? prompt
    guard let normalized = AgentProgressParsing.normalizedTitle(title) else { return nil }
    guard normalized.count > maxPromptTaskLength else { return normalized }
    return String(normalized.prefix(maxPromptTaskLength)) + "…"
  }

  private static func distinguishingLine(
    of prompt: String,
    besides transcript: URL
  ) -> String? {
    guard let runDirectory = workflowRunDirectory(containing: transcript) else { return nil }
    let siblingLines = Set(
      contents(of: runDirectory)
        .filter {
          $0.lastPathComponent.hasPrefix("agent-")
            && $0.pathExtension == "jsonl"
            && $0.lastPathComponent != transcript.lastPathComponent
        }
        .compactMap(ClaudeSubagentTranscriptReader.spawnPrompt(at:))
        .flatMap(promptLines)
    )
    guard !siblingLines.isEmpty else { return nil }
    return promptLines(prompt).first { !siblingLines.contains($0) }
  }

  private static func promptLines(_ prompt: String) -> [String] {
    prompt
      .components(separatedBy: .newlines)
      .compactMap(AgentProgressParsing.normalizedTitle)
  }

  private static func workflowRunDirectory(containing file: URL) -> URL? {
    let runDirectory = file.deletingLastPathComponent()
    let workflows = runDirectory.deletingLastPathComponent()
    guard workflows.lastPathComponent == "workflows",
      workflows.deletingLastPathComponent().lastPathComponent == "subagents"
    else {
      return nil
    }
    return runDirectory
  }

  private static func contents(of directory: URL) -> [URL] {
    (try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    )) ?? []
  }
}
