import Foundation
import Testing

@testable import SupatermSupport

struct AgentDetectionRuleSetTests {
  @Test
  func parsesEveryRuleShape() throws {
    let ruleSet = try parse(
      """
      format_version = 1
      generation = 42
      minimum_engine_version = 1

      [[agents]]
      id = "codex"
      display_name = "Codex"
      processes = [
        { executable = "codex" },
        { executable = "node", script_suffix = "/@openai/codex/bin/codex.js" },
      ]

      [[agents.rules]]
      id = "nested"
      result = "needs_input"
      priority = 100
      region = { source = "screen", last_lines = 8, non_empty = true }
      when = { all = [
        { contains = "Allow command?" },
        { any = [
          { contains_case_insensitive = "press enter" },
          { regex = "confirm|cancel" },
        ] },
        { not = { line_regex = "^Denied$" } },
      ] }

      [[agents.rules]]
      id = "title"
      result = "running"
      priority = 90
      region = { source = "title" }
      when = { regex = "^[⠋⠙] " }
      """
    )

    #expect(ruleSet.formatVersion == 1)
    #expect(ruleSet.generation == 42)
    #expect(ruleSet.minimumEngineVersion == 1)
    #expect(ruleSet.agents.count == 1)
    let agent = try #require(ruleSet.agents.first)
    #expect(agent.id == "codex")
    #expect(agent.displayName == "Codex")
    #expect(agent.processes.count == 2)
    #expect(agent.rules.map(\.id) == ["nested", "title"])
    #expect(agent.rules[0].result == .needsInput)
    #expect(
      agent.rules[0].region
        == AgentDetectionRegion(source: .screen, lastLines: 8, nonEmpty: true)
    )
  }

  @Test(
    arguments: [
      """
      format_version = 1
      generation = 1
      minimum_engine_version = 1
      extra = true
      agents = []
      """,
      """
      format_version = 1
      generation = 1
      minimum_engine_version = 1
      [[agents]]
      id = "codex"
      display_name = "Codex"
      extra = true
      processes = [{ executable = "codex" }]
      rules = []
      """,
      """
      format_version = 1
      generation = 1
      minimum_engine_version = 1
      [[agents]]
      id = "codex"
      display_name = "Codex"
      processes = [{ executable = "codex", extra = true }]
      rules = []
      """,
      """
      format_version = 1
      generation = 1
      minimum_engine_version = 1
      [[agents]]
      id = "codex"
      display_name = "Codex"
      processes = [{ executable = "codex" }]
      [[agents.rules]]
      id = "idle"
      result = "idle"
      priority = 1
      extra = true
      region = { source = "screen" }
      when = { contains = "ready" }
      """,
      """
      format_version = 1
      generation = 1
      minimum_engine_version = 1
      [[agents]]
      id = "codex"
      display_name = "Codex"
      processes = [{ executable = "codex" }]
      [[agents.rules]]
      id = "idle"
      result = "idle"
      priority = 1
      region = { source = "screen", extra = true }
      when = { contains = "ready" }
      """,
      """
      format_version = 1
      generation = 1
      minimum_engine_version = 1
      [[agents]]
      id = "codex"
      display_name = "Codex"
      processes = [{ executable = "codex" }]
      [[agents.rules]]
      id = "idle"
      result = "idle"
      priority = 1
      region = { source = "screen" }
      when = { contains = "ready", extra = true }
      """,
    ]
  )
  func rejectsUnknownKeysAtEveryLevel(toml: String) {
    #expect(throws: (any Error).self) {
      try parse(toml)
    }
  }

  @Test(arguments: [0, 2])
  func rejectsUnsupportedFormatVersion(version: Int) {
    #expect(throws: (any Error).self) {
      try parse(validTOML.replacingOccurrences(of: "format_version = 1", with: "format_version = \(version)"))
    }
  }

  @Test
  func rejectsZeroGeneration() {
    #expect(throws: (any Error).self) {
      try parse(validTOML.replacingOccurrences(of: "generation = 1", with: "generation = 0"))
    }
  }

  @Test(arguments: [0, 2])
  func rejectsInvalidEngineRequirement(version: Int) {
    #expect(throws: (any Error).self) {
      try parse(
        validTOML.replacingOccurrences(
          of: "minimum_engine_version = 1",
          with: "minimum_engine_version = \(version)"
        )
      )
    }
  }

  @Test
  func rejectsFilesLargerThan256KiBBeforeDecoding() {
    let data = Data(repeating: 0x20, count: AgentDetectionRuleSetValidator.maximumDocumentBytes + 1)

    #expect(throws: AgentDetectionRuleSetError.documentTooLarge) {
      try AgentDetectionRuleSetParser.parse(data)
    }
  }

  @Test
  func acceptsDeclaredCollectionLimits() throws {
    let agents = (0..<AgentDetectionRuleSetValidator.maximumAgents)
      .map { agent(index: $0) }
      .joined(separator: "\n")
    let ruleSet = try parse(header + agents)

    #expect(ruleSet.agents.count == AgentDetectionRuleSetValidator.maximumAgents)
  }

  @Test
  func rejectsTooManyAgents() {
    let agents = (0...AgentDetectionRuleSetValidator.maximumAgents)
      .map { agent(index: $0) }
      .joined(separator: "\n")

    #expect(throws: (any Error).self) {
      try parse(header + agents)
    }
  }

  @Test
  func rejectsTooManyProcessRules() {
    let processes = (0...AgentDetectionRuleSetValidator.maximumProcessesPerAgent)
      .map { "{ executable = \"agent-\($0)\" }" }
      .joined(separator: ", ")

    #expect(throws: (any Error).self) {
      try parse(
        header
          + """
          [[agents]]
          id = "agent"
          display_name = "Agent"
          processes = [\(processes)]
          rules = []
          """
      )
    }
  }

  @Test
  func rejectsTooManyRulesForOneAgent() {
    let rules = (0...AgentDetectionRuleSetValidator.maximumRulesPerAgent)
      .map { rule(index: $0) }
      .joined(separator: "\n")

    #expect(throws: (any Error).self) {
      try parse(
        header
          + """
          [[agents]]
          id = "agent"
          display_name = "Agent"
          processes = [{ executable = "agent" }]
          \(rules)
          """
      )
    }
  }

  @Test
  func rejectsDuplicateAgentIDs() {
    #expect(throws: (any Error).self) {
      try parse(header + agent(index: 0) + agent(index: 0))
    }
  }

  @Test
  func rejectsDuplicateProcessesRulesIDsAndPriorities() {
    let documents = [
      validTOML.replacingOccurrences(
        of: "processes = [{ executable = \"codex\" }]",
        with: "processes = [{ executable = \"codex\" }, { executable = \"codex\" }]"
      ),
      validTOML + rule(index: 0),
      validTOML + rule(index: 1).replacingOccurrences(of: "priority = 1", with: "priority = 0"),
    ]

    for document in documents {
      #expect(throws: (any Error).self) {
        try parse(document)
      }
    }
  }

  @Test(arguments: [-10_001, 10_001])
  func rejectsPriorityOutsideBounds(priority: Int) {
    #expect(throws: (any Error).self) {
      try parse(validTOML.replacingOccurrences(of: "priority = 0", with: "priority = \(priority)"))
    }
  }

  @Test(arguments: [0, 65])
  func rejectsLastLinesOutsideBounds(lastLines: Int) {
    #expect(throws: (any Error).self) {
      try parse(
        validTOML.replacingOccurrences(
          of: "region = { source = \"screen\" }",
          with: "region = { source = \"screen\", last_lines = \(lastLines) }"
        )
      )
    }
  }

  @Test(arguments: ["last_lines = 2", "non_empty = true"])
  func rejectsScreenOptionsForTitle(option: String) {
    #expect(throws: (any Error).self) {
      try parse(
        validTOML.replacingOccurrences(
          of: "region = { source = \"screen\" }",
          with: "region = { source = \"title\", \(option) }"
        )
      )
    }
  }

  @Test
  func rejectsEmptyAndAmbiguousExpressions() {
    let expressions = [
      "{}",
      "{ all = [] }",
      "{ any = [] }",
      "{ contains = \"\" }",
      "{ contains = \"ready\", regex = \"ready\" }",
    ]

    for expression in expressions {
      #expect(throws: (any Error).self) {
        try parse(validTOML.replacingOccurrences(of: "{ contains = \"ready\" }", with: expression))
      }
    }
  }

  @Test
  func acceptsEightExpressionLevelsAndRejectsNine() throws {
    let accepted = nestedExpression(depth: AgentDetectionRuleSetValidator.maximumExpressionDepth)
    let rejected = nestedExpression(depth: AgentDetectionRuleSetValidator.maximumExpressionDepth + 1)

    _ = try parse(validTOML.replacingOccurrences(of: "{ contains = \"ready\" }", with: accepted))
    #expect(throws: (any Error).self) {
      try parse(validTOML.replacingOccurrences(of: "{ contains = \"ready\" }", with: rejected))
    }
  }

  @Test
  func rejectsLongPatternsAndInvalidRegexesAtomically() {
    let longPattern = String(repeating: "a", count: AgentDetectionRuleSetValidator.maximumPatternLength + 1)
    let invalidDocuments = [
      validTOML.replacingOccurrences(of: "{ contains = \"ready\" }", with: "{ contains = \"\(longPattern)\" }"),
      validTOML.replacingOccurrences(of: "{ contains = \"ready\" }", with: "{ regex = \"[\" }"),
      validTOML.replacingOccurrences(of: "{ contains = \"ready\" }", with: "{ line_regex = \"[\" }"),
    ]

    for document in invalidDocuments {
      #expect(throws: (any Error).self) {
        try parse(document + agent(index: 1))
      }
    }
  }

  @Test
  func countsPatternLimitsInUTF8Bytes() {
    let pattern = String(repeating: "é", count: 257)

    #expect(throws: (any Error).self) {
      try parse(
        validTOML.replacingOccurrences(
          of: "{ contains = \"ready\" }",
          with: "{ contains = \"\(pattern)\" }"
        )
      )
    }
  }

  @Test
  func rejectsWideAndOversizedExpressionTrees() {
    let wide = (0...AgentDetectionRuleSetValidator.maximumExpressionChildren)
      .map { "{ contains = \"value-\($0)\" }" }
      .joined(separator: ", ")
    let manyRules = (0..<128)
      .map { index in
        let leaves = (0..<8)
          .map { "{ contains = \"value-\(index)-\($0)\" }" }
          .joined(separator: ", ")
        return rule(index: index).replacingOccurrences(
          of: "{ contains = \"ready\" }",
          with: "{ any = [\(leaves)] }"
        )
      }
      .joined(separator: "\n")

    #expect(throws: (any Error).self) {
      try parse(
        validTOML.replacingOccurrences(
          of: "{ contains = \"ready\" }",
          with: "{ any = [\(wide)] }"
        )
      )
    }
    #expect(throws: (any Error).self) {
      try parse(
        header
          + """
          [[agents]]
          id = "agent"
          display_name = "Agent"
          processes = [{ executable = "agent" }]
          \(manyRules)
          """
      )
    }
  }

  @Test(arguments: ["Agent", "agent name", "-agent", "agent/path", "a!"])
  func rejectsNonCanonicalIDs(id: String) {
    #expect(throws: (any Error).self) {
      try parse(
        validTOML.replacingOccurrences(
          of: "id = \"agent-0\"",
          with: "id = \"\(id)\""
        )
      )
    }
  }

  @Test
  func rejectsOverlongIDs() {
    let id = String(repeating: "a", count: 65)

    #expect(throws: (any Error).self) {
      try parse(
        validTOML.replacingOccurrences(
          of: "id = \"agent-0\"",
          with: "id = \"\(id)\""
        )
      )
    }
  }

  @Test(arguments: ["", " Agent", "Agent ", "Agent\n"])
  func rejectsInvalidDisplayNames(displayName: String) {
    let encodedDisplayName = displayName.replacingOccurrences(of: "\n", with: "\\n")

    #expect(
      throws: AgentDetectionRuleSetError.invalidValue("agents[agent-0].display_name")
    ) {
      try parse(
        validTOML.replacingOccurrences(
          of: "display_name = \"Agent 0\"",
          with: "display_name = \"\(encodedDisplayName)\""
        )
      )
    }
  }

  @Test
  func countsDisplayNameLimitInUTF8Bytes() {
    let displayName = String(repeating: "é", count: 65)

    #expect(throws: (any Error).self) {
      try parse(
        validTOML.replacingOccurrences(
          of: "display_name = \"Agent 0\"",
          with: "display_name = \"\(displayName)\""
        )
      )
    }
  }

  @Test(arguments: [" /bin/codex", "/bin/codex", "bin\\codex", ".", ".."])
  func rejectsInvalidExecutableBasenames(executable: String) {
    let encodedExecutable = executable.replacingOccurrences(of: "\\", with: "\\\\")

    #expect(
      throws: AgentDetectionRuleSetError.invalidValue(
        "agents[agent-0].processes[0].executable"
      )
    ) {
      try parse(
        validTOML.replacingOccurrences(
          of: "executable = \"codex\"",
          with: "executable = \"\(encodedExecutable)\""
        )
      )
    }
  }

  @Test(arguments: ["cli.js", "/", " /agent/cli.js"])
  func rejectsInvalidScriptSuffixes(suffix: String) {
    #expect(throws: (any Error).self) {
      try parse(
        validTOML.replacingOccurrences(
          of: "{ executable = \"codex\" }",
          with: "{ executable = \"node\", script_suffix = \"\(suffix)\" }"
        )
      )
    }
  }

  @Test
  func rejectsOverlongExecutableAndScriptSuffix() {
    let executable = String(repeating: "a", count: 256)
    let suffix = "/" + String(repeating: "a", count: 512)

    #expect(throws: (any Error).self) {
      try parse(
        validTOML.replacingOccurrences(
          of: "executable = \"codex\"",
          with: "executable = \"\(executable)\""
        )
      )
    }
    #expect(throws: (any Error).self) {
      try parse(
        validTOML.replacingOccurrences(
          of: "{ executable = \"codex\" }",
          with: "{ executable = \"node\", script_suffix = \"\(suffix)\" }"
        )
      )
    }
  }

  @Test
  func parsesCanonicalCatalog() throws {
    let data = try Data(contentsOf: canonicalCatalogURL)
    let ruleSet = try AgentDetectionRuleSetParser.parse(data)

    #expect(ruleSet.agents.map(\.id) == ["claude", "codex", "pi"])
    #expect(ruleSet.agents.allSatisfy { !$0.rules.isEmpty })
  }

  @Test
  func appBundlesTheCanonicalCatalogWithoutChangingItsBytes() throws {
    let productsURL = Bundle(for: AgentDetectionBundleToken.self).bundleURL
      .deletingLastPathComponent()
    let bundledURL =
      productsURL
      .appendingPathComponent("supaterm.app/Contents/Resources/AgentDetection/rules.toml")
    let bundled = try Data(contentsOf: bundledURL)

    #expect(bundled == (try Data(contentsOf: canonicalCatalogURL)))
    _ = try AgentDetectionRuleSetParser.parse(bundled)
  }

  private var canonicalCatalogURL: URL {
    URL(fileURLWithPath: #filePath)
      .deletingLastPathComponent()
      .deletingLastPathComponent()
      .appendingPathComponent("supaterm/Resources/AgentDetection/rules.toml")
  }

  private var header: String {
    """
    format_version = 1
    generation = 1
    minimum_engine_version = 1

    """
  }

  private var validTOML: String {
    header + agent(index: 0)
  }

  private func agent(index: Int) -> String {
    """
    [[agents]]
    id = "agent-\(index)"
    display_name = "Agent \(index)"
    processes = [{ executable = "codex" }]

    \(rule(index: 0))
    """
  }

  private func rule(index: Int) -> String {
    """
    [[agents.rules]]
    id = "rule-\(index)"
    result = "idle"
    priority = \(index)
    region = { source = "screen" }
    when = { contains = "ready" }
    """
  }

  private func nestedExpression(depth: Int) -> String {
    var expression = "{ contains = \"ready\" }"
    for _ in 0..<depth {
      expression = "{ not = \(expression) }"
    }
    return expression
  }

  private func parse(_ string: String) throws -> AgentDetectionRuleSet {
    try AgentDetectionRuleSetParser.parse(Data(string.utf8))
  }
}

private final class AgentDetectionBundleToken {}
