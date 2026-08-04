import Foundation
import SupatermCLIShared
import Testing

@testable import SPCLI

struct AgentIntegrationPayloadFixtureTests {
  @Test
  func hookTargetRequestEncodesAgentOnly() throws {
    try expectPayloadFixture(SupatermAgentHookTargetRequest(agent: .claude), #"{"agent":"claude"}"#)
    try expectPayloadFixture(SupatermAgentHookTargetRequest(agent: .codex), #"{"agent":"codex"}"#)
    try expectPayloadFixture(SupatermAgentHookTargetRequest(agent: .pi), #"{"agent":"pi"}"#)
    try expectMethodFixture(
      .hooksInstall(SupatermAgentHookTargetRequest(agent: .claude), id: "hooks-install-1"),
      method: SupatermSocketMethod.appHooksInstall,
      params: #"{"agent":"claude"}"#
    )
    try expectMethodFixture(
      .hooksRemove(SupatermAgentHookTargetRequest(agent: .codex), id: "hooks-remove-1"),
      method: SupatermSocketMethod.appHooksRemove,
      params: #"{"agent":"codex"}"#
    )
  }

  @Test
  func hookHealthRequestCarriesNoParams() throws {
    try expectMethodFixture(
      .hooksHealth(id: "hooks-health-1"),
      method: SupatermSocketMethod.appHooksHealth,
      params: "{}"
    )
  }

  @Test
  func hookHealthEncodesAgentAndHealth() throws {
    try expectPayloadFixture(
      SupatermAgentHookHealth(agent: .claude, health: .healthy),
      #"{"agent":"claude","health":"healthy"}"#
    )
  }

  @Test
  func everyHealthCaseEncodesItsRawValue() throws {
    try expectPayloadFixture(
      SupatermAgentHookHealthResult(
        agents: [
          SupatermAgentHookHealth(agent: .claude, health: .unavailable),
          SupatermAgentHookHealth(agent: .codex, health: .unavailableInstalled),
          SupatermAgentHookHealth(agent: .pi, health: .absent),
        ]
      ),
      """
      {"agents":[{"agent":"claude","health":"unavailable"},\
      {"agent":"codex","health":"unavailableInstalled"},\
      {"agent":"pi","health":"absent"}]}
      """
    )
    try expectPayloadFixture(
      SupatermAgentHookHealthResult(
        agents: [
          SupatermAgentHookHealth(agent: .claude, health: .partial),
          SupatermAgentHookHealth(agent: .codex, health: .drifted),
          SupatermAgentHookHealth(agent: .pi, health: .healthy),
        ]
      ),
      """
      {"agents":[{"agent":"claude","health":"partial"},\
      {"agent":"codex","health":"drifted"},\
      {"agent":"pi","health":"healthy"}]}
      """
    )
  }

  @Test
  func skillListRequestsCarryNoParams() throws {
    try expectMethodFixture(
      .skillsList(id: "skills-list-1"),
      method: SupatermSocketMethod.appSkillsList,
      params: "{}"
    )
    try expectMethodFixture(
      .skillsInstall(id: "skills-install-1"),
      method: SupatermSocketMethod.appSkillsInstall,
      params: "{}"
    )
  }

  @Test
  func skillGetRequestEncodesNameAndFull() throws {
    try expectPayloadFixture(
      SupatermSkillGetRequest(name: "core"),
      #"{"full":false,"name":"core"}"#
    )
    try expectMethodFixture(
      .skillsGet(SupatermSkillGetRequest(name: "core", full: true), id: "skills-get-1"),
      method: SupatermSocketMethod.appSkillsGet,
      params: #"{"full":true,"name":"core"}"#
    )
  }

  @Test
  func skillPathRequestEncodesNameOnly() throws {
    try expectPayloadFixture(SupatermSkillPathRequest(name: "core"), #"{"name":"core"}"#)
    try expectMethodFixture(
      .skillsPath(SupatermSkillPathRequest(name: "core"), id: "skills-path-1"),
      method: SupatermSocketMethod.appSkillsPath,
      params: #"{"name":"core"}"#
    )
  }

  @Test
  func skillListResultEncodesEverySummary() throws {
    try expectPayloadFixture(
      SupatermSkillListResult(
        skills: [
          SupatermSkillSummary(name: "coding-agents", description: "Launch coding agents."),
          SupatermSkillSummary(name: "core", description: "Control Supaterm."),
        ]
      ),
      """
      {"skills":[{"description":"Launch coding agents.","name":"coding-agents"},\
      {"description":"Control Supaterm.","name":"core"}]}
      """
    )
  }

  @Test
  func skillContentOmitsFilesUnlessRequested() throws {
    try expectPayloadFixture(
      SupatermSkillContent(name: "core", content: "# Core\n"),
      ##"{"content":"# Core\n","name":"core"}"##
    )
    try expectPayloadFixture(
      SupatermSkillContent(
        name: "core",
        content: "# Core\n",
        files: [SupatermSkillFile(path: "references/tabs.md", content: "Tabs\n")]
      ),
      """
      {"content":"# Core\\n","files":[{"content":"Tabs\\n","path":"references\\/tabs.md"}],\
      "name":"core"}
      """
    )
  }

  @Test
  func skillPathAndInstallResultsEncodePath() throws {
    try expectPayloadFixture(
      SupatermSkillPathResult(path: "/tmp/skill-data/core"),
      #"{"path":"\/tmp\/skill-data\/core"}"#
    )
    try expectPayloadFixture(
      SupatermSkillInstallResult(path: "/tmp/home/.agents/skills/supaterm"),
      #"{"path":"\/tmp\/home\/.agents\/skills\/supaterm"}"#
    )
  }

  @Test
  func settingsValidateRequestOmitsAnAbsentPath() throws {
    try expectPayloadFixture(SupatermSettingsValidateRequest(), "{}")
    try expectPayloadFixture(
      SupatermSettingsValidateRequest(path: "/tmp/settings.toml"),
      #"{"path":"\/tmp\/settings.toml"}"#
    )
    try expectMethodFixture(
      .settingsValidate(id: "settings-validate-1"),
      method: SupatermSocketMethod.appSettingsValidate,
      params: "{}"
    )
    try expectMethodFixture(
      .settingsValidate(
        SupatermSettingsValidateRequest(path: "/tmp/settings.toml"),
        id: "settings-validate-2"
      ),
      method: SupatermSocketMethod.appSettingsValidate,
      params: #"{"path":"\/tmp\/settings.toml"}"#
    )
  }
}

private func expectPayloadFixture<T: Codable & Equatable>(
  _ value: T,
  _ json: String,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let encoded = try jsonString(value)
  #expect(encoded == json, sourceLocation: sourceLocation)
  #expect(
    try JSONDecoder().decode(T.self, from: Data(encoded.utf8)) == value,
    sourceLocation: sourceLocation
  )
}

private func expectMethodFixture(
  _ request: @autoclosure () throws -> SupatermSocketRequest,
  method: String,
  params: String,
  sourceLocation: SourceLocation = #_sourceLocation
) throws {
  let request = try request()
  #expect(request.method == method, sourceLocation: sourceLocation)
  #expect(try jsonString(request.params) == params, sourceLocation: sourceLocation)
  #expect(
    try JSONDecoder().decode(SupatermSocketRequest.self, from: Data(try jsonString(request).utf8))
      == request,
    sourceLocation: sourceLocation
  )
}
