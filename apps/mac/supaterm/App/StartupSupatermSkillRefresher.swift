import Foundation
import SupatermCLIShared

nonisolated struct StartupSupatermSkillRefresher {
  let hasSupatermSkillInstalled: @Sendable () -> Bool
  let installSupatermSkill: @Sendable () throws -> Void
  let logFailure: @Sendable (Error) -> Void

  static let live = StartupSupatermSkillRefresher(
    hasSupatermSkillInstalled: {
      SupatermSkillInstaller().hasSupatermSkillInstalled()
    },
    installSupatermSkill: {
      try SupatermSkillInstaller().installSupatermSkill()
    },
    logFailure: { error in
      let message = "Failed to refresh Supaterm skill at launch."
      AppPostHog.captureException(
        error,
        properties: [
          "category": "agent-skills",
          "message": message,
        ]
      )
    }
  )

  func refreshInstalledSkill() {
    guard hasSupatermSkillInstalled() else { return }
    do {
      try installSupatermSkill()
    } catch {
      logFailure(error)
    }
  }
}
