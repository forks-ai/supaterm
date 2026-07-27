import Foundation
import SupatermCLIShared

nonisolated enum ClaudeSubagentMetadataParser {
  struct Metadata: Equatable {
    let nickname: String?
    let task: String?
  }

  static func metadata(
    transcriptPath: String?,
    agentID: String?
  ) -> Metadata? {
    guard let path = metadataPath(transcriptPath: transcriptPath, agentID: agentID),
      let data = try? Data(contentsOf: path),
      let object = (try? JSONDecoder().decode(JSONValue.self, from: data))?.objectValue
    else {
      return nil
    }
    let nickname = AgentProgressParsing.normalizedTitle(object["name"]?.stringValue)
    let task = AgentProgressParsing.normalizedTitle(object["description"]?.stringValue)
    guard nickname != nil || task != nil else { return nil }
    return Metadata(nickname: nickname, task: task)
  }

  private static func metadataPath(
    transcriptPath: String?,
    agentID: String?
  ) -> URL? {
    guard let transcriptPath, let agentID else { return nil }
    let transcript = URL(fileURLWithPath: transcriptPath)
    guard transcript.pathExtension == "jsonl" else { return nil }
    return
      transcript
      .deletingPathExtension()
      .appendingPathComponent("subagents")
      .appendingPathComponent("agent-\(agentID).meta.json")
  }
}
