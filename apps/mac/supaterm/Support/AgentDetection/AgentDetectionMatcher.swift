import Foundation

public struct AgentDetectionInput: Equatable, Sendable {
  public let screen: String
  public let rawTitle: String

  public init(screen: String, rawTitle: String) {
    self.screen = screen
    self.rawTitle = rawTitle
  }
}

public enum AgentDetectionMatch: Equatable, Sendable {
  case matched(result: AgentDetectionRuleResult, ruleID: String, priority: Int)
  case noMatch
}

struct AgentDetectionMatcher {
  private let rules: [CompiledRule]

  init(agent: AgentDetectionAgentRule) throws {
    rules = try agent.rules.map(CompiledRule.init)
  }

  func match(_ input: AgentDetectionInput) -> AgentDetectionMatch {
    var best: CompiledRule?
    for rule in rules where rule.matches(input) {
      if let currentBest = best {
        if rule.priority > currentBest.priority {
          best = rule
        }
      } else {
        best = rule
      }
    }
    guard let best else { return .noMatch }
    return .matched(result: best.result, ruleID: best.id, priority: best.priority)
  }
}

private struct CompiledRule {
  let id: String
  let result: AgentDetectionRuleResult
  let priority: Int
  let region: AgentDetectionRegion
  let expression: CompiledExpression

  init(_ rule: AgentDetectionStateRule) throws {
    id = rule.id
    result = rule.result
    priority = rule.priority
    region = rule.region
    expression = try CompiledExpression(rule.when)
  }

  func matches(_ input: AgentDetectionInput) -> Bool {
    let text: String
    switch region.source {
    case .title:
      text = input.rawTitle
    case .screen:
      var lines = input.screen.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
      if region.nonEmpty == true {
        lines.removeAll { $0.trimmingCharacters(in: .whitespaces).isEmpty }
      }
      if let lastLines = region.lastLines {
        lines = Array(lines.suffix(lastLines))
      }
      text = lines.joined(separator: "\n")
    }
    return expression.matches(text)
  }
}

private indirect enum CompiledExpression {
  case contains(String)
  case containsCaseInsensitive(String)
  case regex(CompiledRegularExpression)
  case lineRegex(CompiledRegularExpression)
  case all([CompiledExpression])
  case any([CompiledExpression])
  case not(CompiledExpression)

  init(_ expression: AgentDetectionExpression) throws {
    switch expression {
    case .contains(let pattern):
      self = .contains(pattern)
    case .containsCaseInsensitive(let pattern):
      self = .containsCaseInsensitive(pattern)
    case .regex(let pattern):
      self = .regex(try CompiledRegularExpression(pattern))
    case .lineRegex(let pattern):
      self = .lineRegex(try CompiledRegularExpression(pattern))
    case .all(let expressions):
      self = .all(try expressions.map(CompiledExpression.init))
    case .any(let expressions):
      self = .any(try expressions.map(CompiledExpression.init))
    case .not(let expression):
      self = .not(try CompiledExpression(expression))
    }
  }

  func matches(_ text: String) -> Bool {
    switch self {
    case .contains(let pattern):
      text.contains(pattern)
    case .containsCaseInsensitive(let pattern):
      text.range(of: pattern, options: .caseInsensitive) != nil
    case .regex(let expression):
      expression.matches(text)
    case .lineRegex(let expression):
      text.split(separator: "\n", omittingEmptySubsequences: false)
        .contains { expression.matches(String($0)) }
    case .all(let expressions):
      expressions.allSatisfy { $0.matches(text) }
    case .any(let expressions):
      expressions.contains { $0.matches(text) }
    case .not(let expression):
      !expression.matches(text)
    }
  }
}

private struct CompiledRegularExpression {
  private let value: NSRegularExpression

  init(_ pattern: String) throws {
    value = try NSRegularExpression(pattern: pattern)
  }

  func matches(_ string: String) -> Bool {
    value.firstMatch(
      in: string,
      range: NSRange(string.startIndex..<string.endIndex, in: string)
    ) != nil
  }
}
