import CryptoKit
import Foundation
import TOML

struct CodexHookTrustStore {
  struct Entry: Hashable {
    let key: String
    let trustedHash: String
  }

  let fileManager: FileManager

  func trustSupatermHooks(settingsURL: URL, configURL: URL) throws {
    let entries = try supatermHookTrustEntries(settingsURL: settingsURL)
    guard !entries.isEmpty else { return }

    let config = try codexConfig(at: configURL)
    let keys = Set(entries.map(\.key))
    var contents = removingHookStateTables(keys: keys, from: config.contents)

    let blocks = entries.map { entry in
      var state = config.states[entry.key] ?? CodexHookState()
      state.trusted_hash = entry.trustedHash
      return hookStateTable(key: entry.key, state: state)
    }

    if !contents.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      if !contents.hasSuffix("\n") {
        contents += "\n"
      }
      contents += "\n"
    }
    contents += blocks.joined(separator: "\n\n")
    contents += "\n"

    try write(contents, to: configURL)
  }

  func removeTrust(for keys: Set<String>, configURL: URL) throws {
    guard !keys.isEmpty, fileManager.fileExists(atPath: configURL.path) else {
      return
    }

    let config = try codexConfig(at: configURL)
    let contents = removingHookStateTables(keys: keys, from: config.contents)
    guard contents != config.contents else { return }
    try write(contents, to: configURL)
  }

  func supatermHookTrustKeys(settingsURL: URL) throws -> Set<String> {
    Set(try supatermHookTrustEntries(settingsURL: settingsURL).map(\.key))
  }

  func supatermHookTrustEntries(settingsURL: URL) throws -> [Entry] {
    guard fileManager.fileExists(atPath: settingsURL.path) else {
      return []
    }

    let data = try Data(contentsOf: settingsURL)
    let root: JSONValue
    do {
      root = try JSONDecoder().decode(JSONValue.self, from: data)
    } catch {
      throw CodexSettingsInstallerError.invalidJSON
    }
    guard let rootObject = root.objectValue else {
      throw CodexSettingsInstallerError.invalidRootObject
    }
    guard let hooksValue = rootObject["hooks"] else {
      return []
    }
    guard let hooksObject = hooksValue.objectValue else {
      throw CodexSettingsInstallerError.invalidHooksObject
    }

    var entries: [Entry] = []
    for (event, value) in hooksObject {
      guard let eventKey = eventKey(for: event) else { continue }
      guard let groups = value.arrayValue else {
        throw CodexSettingsInstallerError.invalidEventHooks(event)
      }
      for (groupIndex, group) in groups.enumerated() {
        guard let groupObject = group.objectValue else { continue }
        let matcher = matcherForHash(event: event, groupObject: groupObject)
        guard let hooks = groupObject["hooks"]?.arrayValue else { continue }
        for (hookIndex, hook) in hooks.enumerated() {
          guard
            let hookObject = hook.objectValue,
            hookObject["type"]?.stringValue == "command",
            let command = hookObject["command"]?.stringValue,
            AgentHookCommandOwnership.isSupatermManagedCommand(command)
          else {
            continue
          }
          let timeout = max(hookObject["timeout"]?.intValue ?? 600, 1)
          let statusMessage = hookObject["statusMessage"]?.stringValue
          entries.append(
            Entry(
              key: "\(settingsURL.path):\(eventKey):\(groupIndex):\(hookIndex)",
              trustedHash: try trustedHash(
                eventKey: eventKey,
                matcher: matcher,
                command: command,
                timeout: timeout,
                statusMessage: statusMessage
              )
            )
          )
        }
      }
    }
    return entries.sorted { $0.key < $1.key }
  }

  private func codexConfig(at url: URL) throws -> CodexConfig {
    guard fileManager.fileExists(atPath: url.path) else {
      return CodexConfig(contents: "", states: [:])
    }

    let data = try Data(contentsOf: url)
    guard let contents = String(data: data, encoding: .utf8) else {
      throw CodexSettingsInstallerError.invalidConfig
    }

    let decoder = TOMLDecoder()
    do {
      _ = try decoder.decode(EmptyCodexConfig.self, from: data)
    } catch {
      throw CodexSettingsInstallerError.invalidConfig
    }

    let config = try? decoder.decode(CodexConfigFile.self, from: data)
    return CodexConfig(contents: contents, states: config?.hooks?.state ?? [:])
  }

  private func write(_ contents: String, to url: URL) throws {
    try fileManager.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }

  private func removingHookStateTables(keys: Set<String>, from contents: String) -> String {
    let headers = Set(keys.map { hookStateTableHeader(key: $0) })
    let lines = contents.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
    var kept: [String] = []
    var skipping = false

    for line in lines {
      let trimmed = line.trimmingCharacters(in: .whitespaces)
      if headers.contains(trimmed) {
        skipping = true
        continue
      }
      if skipping, isTableHeader(trimmed) {
        skipping = false
      }
      if !skipping {
        kept.append(line)
      }
    }

    return kept.joined(separator: "\n")
  }

  private func hookStateTable(key: String, state: CodexHookState) -> String {
    var lines = [hookStateTableHeader(key: key)]
    if let enabled = state.enabled {
      lines.append("enabled = \(enabled ? "true" : "false")")
    }
    if let trustedHash = state.trusted_hash {
      lines.append(#"trusted_hash = "\#(tomlEscapedStringContent(trustedHash))""#)
    }
    return lines.joined(separator: "\n")
  }

  private func hookStateTableHeader(key: String) -> String {
    #"[hooks.state."\#(tomlEscapedStringContent(key))"]"#
  }

  private func isTableHeader(_ line: String) -> Bool {
    line.hasPrefix("[")
  }

  private func matcherForHash(event: String, groupObject: [String: JSONValue]) -> String? {
    switch event {
    case "Stop", "UserPromptSubmit":
      return nil
    default:
      return groupObject["matcher"]?.stringValue
    }
  }

  private func trustedHash(
    eventKey: String,
    matcher: String?,
    command: String,
    timeout: Int,
    statusMessage: String?
  ) throws -> String {
    var commandHook: [String: Any] = [
      "async": false,
      "command": command,
      "timeout": timeout,
      "type": "command",
    ]
    if let statusMessage {
      commandHook["statusMessage"] = statusMessage
    }

    var identity: [String: Any] = [
      "event_name": eventKey,
      "hooks": [commandHook],
    ]
    if let matcher {
      identity["matcher"] = matcher
    }

    let data = try JSONSerialization.data(
      withJSONObject: identity,
      options: [.sortedKeys, .withoutEscapingSlashes]
    )
    let digest = SHA256.hash(data: data)
    return "sha256:" + digest.map { String(format: "%02x", $0) }.joined()
  }

  private func eventKey(for event: String) -> String? {
    switch event {
    case "PreToolUse":
      return "pre_tool_use"
    case "PermissionRequest":
      return "permission_request"
    case "PostToolUse":
      return "post_tool_use"
    case "PreCompact":
      return "pre_compact"
    case "PostCompact":
      return "post_compact"
    case "SessionStart":
      return "session_start"
    case "UserPromptSubmit":
      return "user_prompt_submit"
    case "Stop":
      return "stop"
    default:
      return nil
    }
  }

  private func tomlEscapedStringContent(_ value: String) -> String {
    var result = ""
    for scalar in value.unicodeScalars {
      switch scalar {
      case "\"":
        result += "\\\""
      case "\\":
        result += "\\\\"
      case "\n":
        result += "\\n"
      case "\r":
        result += "\\r"
      case "\t":
        result += "\\t"
      case "\u{08}":
        result += "\\b"
      case "\u{0C}":
        result += "\\f"
      default:
        if scalar.isASCII, scalar.value < 32 || scalar.value == 127 {
          result += String(format: "\\u%04X", scalar.value)
        } else {
          result.append(Character(scalar))
        }
      }
    }
    return result
  }
}

private struct CodexConfig {
  var contents: String
  var states: [String: CodexHookState]
}

private struct EmptyCodexConfig: Decodable {}

private struct CodexConfigFile: Decodable {
  var hooks: CodexConfigHooks?
}

private struct CodexConfigHooks: Decodable {
  var state: [String: CodexHookState]?
}

private struct CodexHookState: Decodable {
  var enabled: Bool? = nil
  var trusted_hash: String? = nil
}
