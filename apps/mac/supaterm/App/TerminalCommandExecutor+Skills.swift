import Foundation
import SupatermCLIShared
import SupatermSupport

@MainActor
extension TerminalCommandExecutor {
  func skillsList(_ skills: SupatermSkills = SupatermSkills()) throws -> SupatermSkillListResult {
    SupatermSkillListResult(skills: try skills.list())
  }

  func skillsGet(
    _ request: SupatermSkillGetRequest,
    skills: SupatermSkills = SupatermSkills()
  ) throws -> SupatermSkillContent {
    try skills.get(name: request.name, full: request.full)
  }

  func skillsPath(
    _ request: SupatermSkillPathRequest,
    skills: SupatermSkills = SupatermSkills()
  ) throws -> SupatermSkillPathResult {
    SupatermSkillPathResult(path: try skills.path(name: request.name))
  }

  func skillsInstall(
    _ skills: SupatermSkills = SupatermSkills()
  ) throws -> SupatermSkillInstallResult {
    try skills.install()
  }
}
