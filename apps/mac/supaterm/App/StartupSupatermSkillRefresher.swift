import Foundation
import Sentry
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
      AppCrashReporting.withStartedSDK {
        SentrySDK.logger.warn(
          message,
          attributes: [
            "error": error.localizedDescription,
          ]
        )
        let breadcrumb = Breadcrumb(level: .warning, category: "agent-skills")
        breadcrumb.message = message
        breadcrumb.data = [
          "error": error.localizedDescription,
        ]
        SentrySDK.addBreadcrumb(breadcrumb)
      }
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
