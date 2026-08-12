import Foundation
import SupatermCLIShared
import Synchronization

nonisolated enum ClaudeSubagentMetadataParser {
  struct Metadata: Equatable {
    let kind: TerminalAgentChildKind
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
      ?? spawnPromptTask(reading?.spawnPrompt, in: location.runDirectory)
    return Metadata(
      kind:
        object["taskKind"]?.stringValue == "in_process_teammate"
        ? .teammate
        : location.runDirectory == nil ? .subagent : .workflow,
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

  private struct Run {
    var readSpawns: Set<String> = []
    var lineCounts: [String: Int] = [:]
    var countsEveryLine = true
    var lastUsed = 0
  }

  private struct RunTable {
    var runs: [String: Run] = [:]
    var nextUse = 0
  }

  private static let maxPromptTaskLength = 140
  private static let maxRememberedRuns = 8
  private static let maxCountedLines = 256
  private static let maxCountedLineLength = 512
  private static let maxCountedLinesPerRun = 2048
  private static let maxCountedSpawns = 256

  private static let runTable = Mutex(RunTable())

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
    in runDirectory: URL?
  ) -> String? {
    guard let prompt else { return nil }
    let title = runDirectory.flatMap { distinguishingLine(of: prompt, in: $0) } ?? prompt
    guard let normalized = AgentProgressParsing.normalizedTitle(title) else { return nil }
    guard normalized.count > maxPromptTaskLength else { return normalized }
    return String(normalized.prefix(maxPromptTaskLength)) + "…"
  }

  private static func distinguishingLine(
    of prompt: String,
    in runDirectory: URL
  ) -> String? {
    let lines = promptLines(prompt)
    let spawns = contents(of: runDirectory).filter {
      $0.lastPathComponent.hasPrefix("agent-") && $0.pathExtension == "jsonl"
    }
    return runTable.withLock { table in
      var run = table.runs.removeValue(forKey: runDirectory.path) ?? Run()
      var awaitingASpawn = false
      for spawn in spawns
      where run.countsEveryLine && !run.readSpawns.contains(spawn.lastPathComponent) {
        switch ClaudeSubagentTranscriptReader.spawn(at: spawn) {
        case .unwritten:
          awaitingASpawn = true
        case .unreadable:
          run.countsEveryLine = false
        case .prompt(let prompt):
          run.readSpawns.insert(spawn.lastPathComponent)
          merge(promptLines(prompt), into: &run)
        }
      }
      if !run.countsEveryLine {
        run.lineCounts = [:]
        run.readSpawns = []
      }
      if table.runs.count >= maxRememberedRuns,
        let coldest = table.runs.min(by: { $0.value.lastUsed < $1.value.lastUsed })?.key
      {
        table.runs.removeValue(forKey: coldest)
      }
      run.lastUsed = table.nextUse
      table.nextUse += 1
      let line =
        run.countsEveryLine && !awaitingASpawn && run.readSpawns.count > 1
        ? lines.first { run.lineCounts[$0] == 1 }
        : nil
      table.runs[runDirectory.path] = run
      return line
    }
  }

  private static func merge(_ lines: [String], into run: inout Run) {
    guard lines.count <= maxCountedLines,
      lines.allSatisfy({ $0.count <= maxCountedLineLength })
    else {
      run.countsEveryLine = false
      return
    }
    for line in Set(lines) {
      run.lineCounts[line, default: 0] += 1
    }
    run.countsEveryLine =
      run.lineCounts.count <= maxCountedLinesPerRun
      && run.readSpawns.count <= maxCountedSpawns
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
