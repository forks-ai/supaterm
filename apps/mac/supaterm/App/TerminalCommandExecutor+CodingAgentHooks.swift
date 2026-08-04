import Foundation
import SupatermCLIShared

@MainActor
extension TerminalCommandExecutor {
  func hooksInstall(
    _ request: SupatermAgentHookTargetRequest,
    installer: CodingAgentHookInstaller = .live
  ) async throws -> SupatermAgentHookHealth {
    try await Task.detached(priority: .utility) {
      try installer.installSupatermHooks(request.agent)
      return SupatermAgentHookHealth(
        agent: request.agent,
        health: try installer.integrationHealth(request.agent)
      )
    }.value
  }

  func hooksRemove(
    _ request: SupatermAgentHookTargetRequest,
    installer: CodingAgentHookInstaller = .live
  ) async throws -> SupatermAgentHookHealth {
    try await Task.detached(priority: .utility) {
      try installer.removeSupatermHooks(request.agent)
      return SupatermAgentHookHealth(
        agent: request.agent,
        health: try installer.integrationHealth(request.agent)
      )
    }.value
  }

  func hooksHealth(
    installer: CodingAgentHookInstaller = .live
  ) async throws -> SupatermAgentHookHealthResult {
    try await Task.detached(priority: .utility) {
      SupatermAgentHookHealthResult(
        agents: try SupatermAgentKind.allCases.map {
          SupatermAgentHookHealth(agent: $0, health: try installer.integrationHealth($0))
        }
      )
    }.value
  }
}
