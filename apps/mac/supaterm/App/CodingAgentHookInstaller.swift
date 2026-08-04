import Foundation
import SupatermCLIShared
import SupatermSupport

nonisolated struct CodingAgentHookInstaller: Sendable {
  let integrationHealth: @Sendable (SupatermAgentKind) throws -> CodingAgentIntegrationHealth
  let installSupatermHooks: @Sendable (SupatermAgentKind) throws -> Void
  let removeSupatermHooks: @Sendable (SupatermAgentKind) throws -> Void

  static let live = Self(
    integrationHealth: { agent in
      switch agent {
      case .claude:
        return try ClaudeSettingsInstaller().integrationHealth()
      case .codex:
        return try CodexSettingsInstaller().integrationHealth()
      case .pi:
        return try PiSettingsInstaller().integrationHealth()
      }
    },
    installSupatermHooks: { agent in
      switch agent {
      case .claude:
        try ClaudeSettingsInstaller().installSupatermHooks()
      case .codex:
        try CodexSettingsInstaller().installSupatermHooks()
      case .pi:
        try PiSettingsInstaller().installSupatermPackage()
      }
    },
    removeSupatermHooks: { agent in
      switch agent {
      case .claude:
        try ClaudeSettingsInstaller().removeSupatermHooks()
      case .codex:
        try CodexSettingsInstaller().removeSupatermHooks()
      case .pi:
        try PiSettingsInstaller().removeSupatermPackage()
      }
    }
  )
}
