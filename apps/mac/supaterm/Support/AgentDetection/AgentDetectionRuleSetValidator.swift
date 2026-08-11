import Foundation

enum AgentDetectionRuleSetValidator {
  static let currentFormatVersion: UInt = 1
  static let currentEngineVersion: UInt = 1
  static let maximumDocumentBytes = 256 * 1_024
  static let maximumAgents = 64
  static let maximumProcessesPerAgent = 16
  static let maximumRulesPerAgent = 128
  static let maximumExpressionDepth = 8
  static let maximumExpressionChildren = 32
  static let maximumExpressions = 1_024
  static let maximumDisplayNameLength = 128
  static let maximumPatternLength = 512
  static let maximumExecutableLength = 255
  static let maximumScriptSuffixLength = 512
  static let priorityRange = -10_000...10_000
  static let lastLinesRange = 1...64

  static func validate(_ ruleSet: AgentDetectionRuleSet) throws {
    guard ruleSet.formatVersion == currentFormatVersion else {
      throw AgentDetectionRuleSetError.invalidValue("format_version")
    }
    guard ruleSet.generation > 0 else {
      throw AgentDetectionRuleSetError.invalidValue("generation")
    }
    guard
      ruleSet.minimumEngineVersion > 0,
      ruleSet.minimumEngineVersion <= currentEngineVersion
    else {
      throw AgentDetectionRuleSetError.invalidValue("minimum_engine_version")
    }
    guard !ruleSet.agents.isEmpty else {
      throw AgentDetectionRuleSetError.invalidValue("agents")
    }
    guard ruleSet.agents.count <= maximumAgents else {
      throw AgentDetectionRuleSetError.limitExceeded("agents")
    }
    guard Set(ruleSet.agents.map(\.id)).count == ruleSet.agents.count else {
      throw AgentDetectionRuleSetError.duplicateValue("agents.id")
    }

    var expressionCount = 0
    for agent in ruleSet.agents {
      expressionCount += try validateAgent(agent)
      guard expressionCount <= maximumExpressions else {
        throw AgentDetectionRuleSetError.limitExceeded("agents.rules.when")
      }
    }
  }

  private static func validateAgent(_ agent: AgentDetectionAgentRule) throws -> Int {
    let path = "agents[\(agent.id)]"
    guard validID(agent.id) else {
      throw AgentDetectionRuleSetError.invalidValue("\(path).id")
    }
    let displayName = agent.displayName
    guard
      displayName == displayName.trimmingCharacters(in: .whitespacesAndNewlines),
      !displayName.isEmpty,
      displayName.utf8.count <= maximumDisplayNameLength,
      displayName.unicodeScalars.allSatisfy({ $0.value >= 0x20 && $0.value != 0x7F })
    else {
      throw AgentDetectionRuleSetError.invalidValue("\(path).display_name")
    }
    try validate(agent.processes, path: path)
    guard !agent.rules.isEmpty else {
      throw AgentDetectionRuleSetError.invalidValue("\(path).rules")
    }
    guard agent.rules.count <= maximumRulesPerAgent else {
      throw AgentDetectionRuleSetError.limitExceeded("\(path).rules")
    }
    guard Set(agent.rules.map(\.id)).count == agent.rules.count else {
      throw AgentDetectionRuleSetError.duplicateValue("\(path).rules.id")
    }
    guard Set(agent.rules.map(\.priority)).count == agent.rules.count else {
      throw AgentDetectionRuleSetError.duplicateValue("\(path).rules.priority")
    }

    var expressionCount = 0
    for rule in agent.rules {
      guard validID(rule.id) else {
        throw AgentDetectionRuleSetError.invalidValue("\(path).rules[\(rule.id)].id")
      }
      try validate(
        rule,
        path: "\(path).rules[\(rule.id)]",
        expressionCount: &expressionCount
      )
      guard expressionCount <= maximumExpressions else {
        throw AgentDetectionRuleSetError.limitExceeded("\(path).rules.when")
      }
    }
    return expressionCount
  }

  private static func validate(
    _ processes: [AgentDetectionProcessRule],
    path: String
  ) throws {
    guard !processes.isEmpty else {
      throw AgentDetectionRuleSetError.invalidValue("\(path).processes")
    }
    guard processes.count <= maximumProcessesPerAgent else {
      throw AgentDetectionRuleSetError.limitExceeded("\(path).processes")
    }
    guard Set(processes).count == processes.count else {
      throw AgentDetectionRuleSetError.duplicateValue("\(path).processes")
    }
    for (index, process) in processes.enumerated() {
      let executable = process.executable
      guard
        executable == executable.trimmingCharacters(in: .whitespacesAndNewlines),
        !executable.isEmpty,
        executable.utf8.count <= maximumExecutableLength,
        executable != ".",
        executable != "..",
        !executable.contains("/"),
        !executable.contains("\\")
      else {
        throw AgentDetectionRuleSetError.invalidValue("\(path).processes[\(index)].executable")
      }
      if let suffix = process.scriptSuffix {
        guard
          suffix == suffix.trimmingCharacters(in: .whitespacesAndNewlines),
          suffix.count > 1,
          suffix.utf8.count <= maximumScriptSuffixLength,
          suffix.hasPrefix("/")
        else {
          throw AgentDetectionRuleSetError.invalidValue("\(path).processes[\(index)].script_suffix")
        }
      }
    }
  }

  private static func validate(
    _ rule: AgentDetectionStateRule,
    path: String,
    expressionCount: inout Int
  ) throws {
    guard priorityRange.contains(rule.priority) else {
      throw AgentDetectionRuleSetError.invalidValue("\(path).priority")
    }
    switch rule.region.source {
    case .screen:
      if let lastLines = rule.region.lastLines, !lastLinesRange.contains(lastLines) {
        throw AgentDetectionRuleSetError.invalidValue("\(path).region.last_lines")
      }
    case .title:
      guard rule.region.lastLines == nil, rule.region.nonEmpty == nil else {
        throw AgentDetectionRuleSetError.invalidValue("\(path).region")
      }
    }
    try validate(
      rule.when,
      path: "\(path).when",
      depth: 0,
      expressionCount: &expressionCount
    )
  }

  private static func validate(
    _ expression: AgentDetectionExpression,
    path: String,
    depth: Int,
    expressionCount: inout Int
  ) throws {
    guard depth <= maximumExpressionDepth else {
      throw AgentDetectionRuleSetError.limitExceeded(path)
    }
    expressionCount += 1
    guard expressionCount <= maximumExpressions else {
      throw AgentDetectionRuleSetError.limitExceeded(path)
    }

    switch expression {
    case .contains(let pattern), .containsCaseInsensitive(let pattern):
      try validate(pattern, path: path, regularExpression: false)
    case .regex(let pattern), .lineRegex(let pattern):
      try validate(pattern, path: path, regularExpression: true)
    case .all(let expressions), .any(let expressions):
      guard !expressions.isEmpty else {
        throw AgentDetectionRuleSetError.invalidValue(path)
      }
      guard expressions.count <= maximumExpressionChildren else {
        throw AgentDetectionRuleSetError.limitExceeded(path)
      }
      for (index, expression) in expressions.enumerated() {
        try validate(
          expression,
          path: "\(path)[\(index)]",
          depth: depth + 1,
          expressionCount: &expressionCount
        )
      }
    case .not(let expression):
      try validate(
        expression,
        path: "\(path).not",
        depth: depth + 1,
        expressionCount: &expressionCount
      )
    }
  }

  private static func validate(
    _ pattern: String,
    path: String,
    regularExpression: Bool
  ) throws {
    guard !pattern.isEmpty else {
      throw AgentDetectionRuleSetError.invalidValue(path)
    }
    guard pattern.utf8.count <= maximumPatternLength else {
      throw AgentDetectionRuleSetError.limitExceeded(path)
    }
    if regularExpression {
      do {
        _ = try NSRegularExpression(pattern: pattern)
      } catch {
        throw AgentDetectionRuleSetError.invalidRegularExpression(path)
      }
    }
  }

  private static func validID(_ id: String) -> Bool {
    guard !id.isEmpty, id.utf8.count <= 64 else { return false }
    return id.utf8.enumerated().allSatisfy { index, byte in
      let letter = (UInt8(ascii: "a")...UInt8(ascii: "z")).contains(byte)
      let digit = (UInt8(ascii: "0")...UInt8(ascii: "9")).contains(byte)
      return letter || digit
        || (index > 0 && (byte == UInt8(ascii: "_") || byte == UInt8(ascii: "-")))
    }
  }
}
