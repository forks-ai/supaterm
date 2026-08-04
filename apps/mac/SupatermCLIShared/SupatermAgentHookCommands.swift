import Foundation

public struct SupatermAgentHookTargetRequest: Codable, Equatable, Sendable {
  public let agent: SupatermAgentKind

  public init(agent: SupatermAgentKind) {
    self.agent = agent
  }
}

public struct SupatermAgentHookHealth: Codable, Equatable, Sendable {
  public let agent: SupatermAgentKind
  public let health: CodingAgentIntegrationHealth

  public init(agent: SupatermAgentKind, health: CodingAgentIntegrationHealth) {
    self.agent = agent
    self.health = health
  }
}

public struct SupatermAgentHookHealthResult: Codable, Equatable, Sendable {
  public let agents: [SupatermAgentHookHealth]

  public init(agents: [SupatermAgentHookHealth]) {
    self.agents = agents
  }
}
