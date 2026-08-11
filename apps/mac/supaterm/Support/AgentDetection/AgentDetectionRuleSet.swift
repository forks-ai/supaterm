import Foundation

struct AgentDetectionRuleSet: Decodable, Equatable, Sendable {
  let formatVersion: UInt
  let generation: UInt64
  let minimumEngineVersion: UInt
  let agents: [AgentDetectionAgentRule]

  init(from decoder: any Decoder) throws {
    let container = try decoder.agentDetectionContainer(keyedBy: CodingKeys.self)
    formatVersion = try container.decode(UInt.self, forKey: .formatVersion)
    generation = try container.decode(UInt64.self, forKey: .generation)
    minimumEngineVersion = try container.decode(UInt.self, forKey: .minimumEngineVersion)
    agents = try container.decode([AgentDetectionAgentRule].self, forKey: .agents)
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case formatVersion = "format_version"
    case generation
    case minimumEngineVersion = "minimum_engine_version"
    case agents
  }
}

struct AgentDetectionAgentRule: Decodable, Equatable, Sendable {
  let id: String
  let displayName: String
  let processes: [AgentDetectionProcessRule]
  let rules: [AgentDetectionStateRule]

  init(
    id: String,
    displayName: String,
    processes: [AgentDetectionProcessRule],
    rules: [AgentDetectionStateRule]
  ) {
    self.id = id
    self.displayName = displayName
    self.processes = processes
    self.rules = rules
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.agentDetectionContainer(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    displayName = try container.decode(String.self, forKey: .displayName)
    processes = try container.decode([AgentDetectionProcessRule].self, forKey: .processes)
    rules = try container.decode([AgentDetectionStateRule].self, forKey: .rules)
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case id
    case displayName = "display_name"
    case processes
    case rules
  }
}

struct AgentDetectionStateRule: Decodable, Equatable, Sendable {
  let id: String
  let result: AgentDetectionRuleResult
  let priority: Int
  let region: AgentDetectionRegion
  let when: AgentDetectionExpression

  init(
    id: String,
    result: AgentDetectionRuleResult,
    priority: Int,
    region: AgentDetectionRegion,
    when: AgentDetectionExpression
  ) {
    self.id = id
    self.result = result
    self.priority = priority
    self.region = region
    self.when = when
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.agentDetectionContainer(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    result = try container.decode(AgentDetectionRuleResult.self, forKey: .result)
    priority = try container.decode(Int.self, forKey: .priority)
    region = try container.decode(AgentDetectionRegion.self, forKey: .region)
    when = try container.decode(AgentDetectionExpression.self, forKey: .when)
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case id
    case result
    case priority
    case region
    case when
  }
}

public enum AgentDetectionRuleResult: String, Decodable, Equatable, Sendable {
  case running
  case needsInput = "needs_input"
  case idle
  case hold
}

struct AgentDetectionRegion: Decodable, Equatable, Sendable {
  let source: Source
  let lastLines: Int?
  let nonEmpty: Bool?

  init(source: Source, lastLines: Int? = nil, nonEmpty: Bool? = nil) {
    self.source = source
    self.lastLines = lastLines
    self.nonEmpty = nonEmpty
  }

  init(from decoder: any Decoder) throws {
    let container = try decoder.agentDetectionContainer(keyedBy: CodingKeys.self)
    source = try container.decode(Source.self, forKey: .source)
    lastLines = try container.decodeIfPresent(Int.self, forKey: .lastLines)
    nonEmpty = try container.decodeIfPresent(Bool.self, forKey: .nonEmpty)
  }

  enum Source: String, Decodable, Equatable, Sendable {
    case screen
    case title
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case source
    case lastLines = "last_lines"
    case nonEmpty = "non_empty"
  }
}

indirect enum AgentDetectionExpression: Decodable, Equatable, Sendable {
  case contains(String)
  case containsCaseInsensitive(String)
  case regex(String)
  case lineRegex(String)
  case all([AgentDetectionExpression])
  case any([AgentDetectionExpression])
  case not(AgentDetectionExpression)

  init(from decoder: any Decoder) throws {
    let container = try decoder.agentDetectionContainer(keyedBy: CodingKeys.self)
    guard container.allKeys.count == 1, let key = container.allKeys.first else {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: decoder.codingPath,
          debugDescription: "An agent detection expression must contain exactly one operator."
        )
      )
    }

    switch key {
    case .contains:
      self = .contains(try container.decode(String.self, forKey: key))
    case .containsCaseInsensitive:
      self = .containsCaseInsensitive(try container.decode(String.self, forKey: key))
    case .regex:
      self = .regex(try container.decode(String.self, forKey: key))
    case .lineRegex:
      self = .lineRegex(try container.decode(String.self, forKey: key))
    case .all:
      self = .all(try container.decode([AgentDetectionExpression].self, forKey: key))
    case .any:
      self = .any(try container.decode([AgentDetectionExpression].self, forKey: key))
    case .not:
      self = .not(try container.decode(AgentDetectionExpression.self, forKey: key))
    }
  }

  private enum CodingKeys: String, CodingKey, CaseIterable {
    case contains
    case containsCaseInsensitive = "contains_case_insensitive"
    case regex
    case lineRegex = "line_regex"
    case all
    case any
    case not
  }
}

struct AgentDetectionCodingKey: CodingKey, Hashable {
  let stringValue: String
  let intValue: Int?

  init?(stringValue: String) {
    self.stringValue = stringValue
    intValue = nil
  }

  init?(intValue: Int) {
    stringValue = "\(intValue)"
    self.intValue = intValue
  }
}

extension Decoder {
  func agentDetectionContainer<Key>(
    keyedBy type: Key.Type
  ) throws -> KeyedDecodingContainer<Key> where Key: CodingKey & CaseIterable {
    let dynamic = try container(keyedBy: AgentDetectionCodingKey.self)
    let allowed = Set(Key.allCases.map(\.stringValue))
    if let unknown = dynamic.allKeys.first(where: { !allowed.contains($0.stringValue) }) {
      throw DecodingError.dataCorrupted(
        DecodingError.Context(
          codingPath: codingPath + [unknown],
          debugDescription: "Unknown agent detection key '\(unknown.stringValue)'."
        )
      )
    }
    return try container(keyedBy: type)
  }
}
