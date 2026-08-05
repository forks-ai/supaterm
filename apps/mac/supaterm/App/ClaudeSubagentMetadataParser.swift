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
      ?? spawnPromptTask(reading?.spawnPrompt)
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
    let workflowRuns =
      (try? FileManager.default.contentsOfDirectory(
        at: workflows,
        includingPropertiesForKeys: nil
      )) ?? []
    return
      workflowRuns
      .map {
        workflows.appendingPathComponent($0.lastPathComponent).appendingPathComponent(fileName)
      }
      .first { FileManager.default.fileExists(atPath: $0.path) }
  }

  private static func workflowName(besides metadataURL: URL) -> String? {
    let runDirectory = metadataURL.deletingLastPathComponent()
    guard runDirectory.deletingLastPathComponent().lastPathComponent == "workflows" else {
      return nil
    }
    let suffix = "-\(runDirectory.lastPathComponent).js"
    let scriptsDirectory =
      runDirectory
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("workflows")
      .appendingPathComponent("scripts")
    let scripts =
      (try? FileManager.default.contentsOfDirectory(
        at: scriptsDirectory,
        includingPropertiesForKeys: nil
      )) ?? []
    guard
      let script =
        scripts
        .map(\.lastPathComponent)
        .first(where: { $0.hasSuffix(suffix) })
    else {
      return nil
    }
    return AgentProgressParsing.normalizedTitle(String(script.dropLast(suffix.count)))
  }

  private static func spawnPromptTask(_ prompt: String?) -> String? {
    guard let normalized = AgentProgressParsing.normalizedTitle(prompt) else { return nil }
    guard normalized.count > maxPromptTaskLength else { return normalized }
    return String(normalized.prefix(maxPromptTaskLength)) + "…"
  }
}
