import Foundation
import SupatermCLIShared
import Synchronization

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
    guard let transcriptPath,
      let agentID,
      let location = location(transcriptPath: transcriptPath, agentID: agentID),
      let data = try? Data(contentsOf: location.metadataURL),
      let object = (try? JSONDecoder().decode(JSONValue.self, from: data))?.objectValue
    else {
      return nil
    }
    let childTranscript =
      location
      .metadataURL
      .deletingLastPathComponent()
      .appendingPathComponent("agent-\(agentID).jsonl")
    let reading = ClaudeSubagentTranscriptReader.read(at: childTranscript)
    let nickname =
      AgentProgressParsing.normalizedTitle(object["name"]?.stringValue)
      ?? location.runDirectory.flatMap {
        workflowName(of: $0, under: URL(fileURLWithPath: transcriptPath))
      }
    let task =
      AgentProgressParsing.normalizedTitle(object["description"]?.stringValue)
      ?? spawnPromptTask(reading?.spawnPrompt, besides: childTranscript, in: location.runDirectory)
    return Metadata(
      nickname: nickname,
      task: task,
      transcriptPath: childTranscript.path,
      usage: reading?.usage
    )
  }

  private struct Location {
    let metadataURL: URL
    let runDirectory: URL?
  }

  private static let maxPromptTaskLength = 140
  private static let maxRememberedSpawns = 1024

  private static let spawnPromptLines = Mutex<[String: [String]]>([:])

  private static func location(
    transcriptPath: String,
    agentID: String
  ) -> Location? {
    let transcript = URL(fileURLWithPath: transcriptPath)
    guard transcript.pathExtension == "jsonl" else { return nil }
    let subagents =
      transcript
      .deletingPathExtension()
      .appendingPathComponent("subagents")
    let fileName = "agent-\(agentID).meta.json"
    let direct = subagents.appendingPathComponent(fileName)
    if FileManager.default.fileExists(atPath: direct.path) {
      return Location(metadataURL: direct, runDirectory: nil)
    }
    let workflows = subagents.appendingPathComponent("workflows")
    for run in contents(of: workflows) {
      let runDirectory = workflows.appendingPathComponent(run.lastPathComponent)
      let candidate = runDirectory.appendingPathComponent(fileName)
      if FileManager.default.fileExists(atPath: candidate.path) {
        return Location(metadataURL: candidate, runDirectory: runDirectory)
      }
    }
    return nil
  }

  private static func workflowName(of runDirectory: URL, under transcript: URL) -> String? {
    let suffix = "-\(runDirectory.lastPathComponent).js"
    let scriptsDirectory =
      transcript
      .deletingPathExtension()
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
    besides transcript: URL,
    in runDirectory: URL?
  ) -> String? {
    guard let prompt else { return nil }
    let title =
      runDirectory.flatMap { distinguishingLine(of: prompt, besides: transcript, in: $0) }
      ?? prompt
    guard let normalized = AgentProgressParsing.normalizedTitle(title) else { return nil }
    guard normalized.count > maxPromptTaskLength else { return normalized }
    return String(normalized.prefix(maxPromptTaskLength)) + "…"
  }

  private static func distinguishingLine(
    of prompt: String,
    besides transcript: URL,
    in runDirectory: URL
  ) -> String? {
    let siblingLines = Set(
      contents(of: runDirectory)
        .filter {
          $0.lastPathComponent.hasPrefix("agent-")
            && $0.pathExtension == "jsonl"
            && $0.lastPathComponent != transcript.lastPathComponent
        }
        .flatMap(spawnPromptLines(at:))
    )
    guard !siblingLines.isEmpty else { return nil }
    return promptLines(prompt).first { !siblingLines.contains($0) }
  }

  private static func spawnPromptLines(at url: URL) -> [String] {
    if let remembered = spawnPromptLines.withLock({ $0[url.path] }) {
      return remembered
    }
    guard let prompt = ClaudeSubagentTranscriptReader.spawnPrompt(at: url) else { return [] }
    let lines = promptLines(prompt)
    guard !lines.isEmpty else { return [] }
    spawnPromptLines.withLock {
      if $0.count >= maxRememberedSpawns {
        $0.removeAll(keepingCapacity: true)
      }
      $0[url.path] = lines
    }
    return lines
  }

  private static func promptLines(_ prompt: String) -> [String] {
    prompt
      .components(separatedBy: .newlines)
      .compactMap(AgentProgressParsing.normalizedTitle)
  }

  private static func contents(of directory: URL) -> [URL] {
    (try? FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: nil
    )) ?? []
  }
}
