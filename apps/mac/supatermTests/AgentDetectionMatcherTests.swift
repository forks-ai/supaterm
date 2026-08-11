import Foundation
import Testing

@testable import SupatermSupport

struct AgentDetectionMatcherTests {
  @Test
  func selectsTheHighestPriorityMatch() throws {
    let matcher = try AgentDetectionMatcher(
      agent: agent(
        rules: [
          rule(id: "idle", result: .idle, priority: 10, when: .contains("ready")),
          rule(id: "input", result: .needsInput, priority: 20, when: .contains("ready")),
        ]
      )
    )

    #expect(
      matcher.match(AgentDetectionInput(screen: "ready", rawTitle: ""))
        == .matched(result: .needsInput, ruleID: "input", priority: 20)
    )
  }

  @Test
  func noMatchingRuleIsUnknownEvidence() throws {
    let matcher = try AgentDetectionMatcher(
      agent: agent(rules: [rule(when: .contains("ready"))])
    )

    #expect(matcher.match(AgentDetectionInput(screen: "working", rawTitle: "")) == .noMatch)
  }

  @Test
  func selectsRawAndNonEmptyScreenLines() throws {
    let rawMatcher = try AgentDetectionMatcher(
      agent: agent(
        rules: [
          rule(
            region: AgentDetectionRegion(source: .screen, lastLines: 2, nonEmpty: false),
            when: .contains("second")
          )
        ]
      )
    )
    let nonEmptyMatcher = try AgentDetectionMatcher(
      agent: agent(
        rules: [
          rule(
            region: AgentDetectionRegion(source: .screen, lastLines: 2, nonEmpty: true),
            when: .contains("second")
          )
        ]
      )
    )
    let input = AgentDetectionInput(screen: "first\nsecond\n\nthird", rawTitle: "")

    #expect(rawMatcher.match(input) == .noMatch)
    #expect(nonEmptyMatcher.match(input) != .noMatch)
  }

  @Test
  func titleRulesDoNotInspectTheScreen() throws {
    let matcher = try AgentDetectionMatcher(
      agent: agent(
        rules: [
          rule(region: AgentDetectionRegion(source: .title), when: .contains("Action Required"))
        ]
      )
    )

    #expect(
      matcher.match(AgentDetectionInput(screen: "Action Required", rawTitle: "project")) == .noMatch
    )
    #expect(
      matcher.match(AgentDetectionInput(screen: "", rawTitle: "Action Required | project"))
        != .noMatch
    )
  }

  @Test
  func evaluatesEveryLeafExpression() throws {
    let expressions: [(AgentDetectionExpression, String)] = [
      (.contains("Ready"), "Ready"),
      (.containsCaseInsensitive("ready"), "READY"),
      (.regex("R.*y"), "Ready"),
      (.lineRegex("^Ready$"), "before\nReady\nafter"),
    ]

    for (expression, screen) in expressions {
      let matcher = try AgentDetectionMatcher(agent: agent(rules: [rule(when: expression)]))
      #expect(matcher.match(AgentDetectionInput(screen: screen, rawTitle: "")) != .noMatch)
    }
  }

  @Test
  func evaluatesRecursiveBooleanExpressions() throws {
    let matcher = try AgentDetectionMatcher(
      agent: agent(
        rules: [
          rule(
            when: .all([
              .contains("Ready"),
              .any([.contains("Enter"), .contains("Return")]),
              .not(.contains("Denied")),
            ])
          )
        ]
      )
    )

    #expect(
      matcher.match(AgentDetectionInput(screen: "Ready\nPress Enter", rawTitle: "")) != .noMatch
    )
    #expect(
      matcher.match(AgentDetectionInput(screen: "Ready\nPress Enter\nDenied", rawTitle: ""))
        == .noMatch
    )
  }

  @Test
  func regexMatchesAcrossTheRegionWhileLineRegexChecksEachLine() throws {
    let wholeMatcher = try AgentDetectionMatcher(
      agent: agent(rules: [rule(when: .regex("(?s)start.*finish"))])
    )
    let lineMatcher = try AgentDetectionMatcher(
      agent: agent(rules: [rule(when: .lineRegex("^start.*finish$"))])
    )
    let input = AgentDetectionInput(screen: "start\nmiddle\nfinish", rawTitle: "")

    #expect(wholeMatcher.match(input) != .noMatch)
    #expect(lineMatcher.match(input) == .noMatch)
  }

  @Test(arguments: ["claude-needs-input", "codex-needs-input"])
  func canonicalPermissionFixturesNeedInput(name: String) throws {
    let fixture = try fixture(name: name)
    let agentID = String(name.prefix { $0 != "-" })
    let agent = try #require(fixture.ruleSet.agents.first { $0.id == agentID })
    let matcher = try AgentDetectionMatcher(agent: agent)

    guard
      case .matched(let result, _, _) = matcher.match(
        AgentDetectionInput(screen: fixture.screen, rawTitle: fixture.title)
      )
    else {
      Issue.record("Expected a matched permission rule")
      return
    }
    #expect(result == .needsInput)
  }

  @Test(arguments: ["claude-running", "codex-running", "pi-running"])
  func canonicalWorkingFixturesAreRunning(name: String) throws {
    let fixture = try fixture(name: name)
    let agentID = String(name.prefix { $0 != "-" })
    let agent = try #require(fixture.ruleSet.agents.first { $0.id == agentID })
    let matcher = try AgentDetectionMatcher(agent: agent)

    guard
      case .matched(let result, _, _) = matcher.match(
        AgentDetectionInput(screen: fixture.screen, rawTitle: fixture.title)
      )
    else {
      Issue.record("Expected a matched running rule")
      return
    }
    #expect(result == .running)
  }

  @Test(arguments: ["claude-transcript", "codex-transcript"])
  func canonicalTranscriptFixturesHoldThePriorState(name: String) throws {
    let fixture = try fixture(name: name)
    let agentID = String(name.prefix { $0 != "-" })
    let agent = try #require(fixture.ruleSet.agents.first { $0.id == agentID })
    let matcher = try AgentDetectionMatcher(agent: agent)

    guard
      case .matched(let result, _, _) = matcher.match(
        AgentDetectionInput(screen: fixture.screen, rawTitle: fixture.title)
      )
    else {
      Issue.record("Expected a matched transcript rule")
      return
    }
    #expect(result == .hold)
  }

  private func agent(rules: [AgentDetectionStateRule]) -> AgentDetectionAgentRule {
    AgentDetectionAgentRule(
      id: "agent",
      displayName: "Agent",
      processes: [AgentDetectionProcessRule(executable: "agent")],
      rules: rules
    )
  }

  private func rule(
    id: String = "rule",
    result: AgentDetectionRuleResult = .running,
    priority: Int = 0,
    region: AgentDetectionRegion = AgentDetectionRegion(source: .screen),
    when: AgentDetectionExpression
  ) -> AgentDetectionStateRule {
    AgentDetectionStateRule(
      id: id,
      result: result,
      priority: priority,
      region: region,
      when: when
    )
  }

  private func fixture(name: String) throws -> Fixture {
    let fixtureURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .appendingPathComponent("Fixtures/AgentDetection/\(name).txt")
    let contents = try String(contentsOf: fixtureURL, encoding: .utf8)
    let lines = contents.split(separator: "\n", omittingEmptySubsequences: false)
    let title = lines.first.map(String.init) ?? ""
    let screen = lines.dropFirst(2).joined(separator: "\n")
    let catalogURL = URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("supaterm/Resources/AgentDetection/rules.toml")
    let ruleSet = try AgentDetectionRuleSetParser.parse(Data(contentsOf: catalogURL))
    return Fixture(ruleSet: ruleSet, screen: screen, title: title)
  }

  private struct Fixture {
    let ruleSet: AgentDetectionRuleSet
    let screen: String
    let title: String
  }
}
