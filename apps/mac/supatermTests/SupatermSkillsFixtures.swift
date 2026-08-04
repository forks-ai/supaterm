import Foundation

func temporarySkillsRoot() throws -> URL {
  try FileManager.default.url(
    for: .itemReplacementDirectory,
    in: .userDomainMask,
    appropriateFor: FileManager.default.temporaryDirectory,
    create: true
  )
}

func bundledSkillsDirectory(in rootURL: URL) throws -> URL {
  let bundledSkillsDirectoryURL =
    rootURL
    .appendingPathComponent("Supaterm.app", isDirectory: true)
    .appendingPathComponent("Contents", isDirectory: true)
    .appendingPathComponent("Resources", isDirectory: true)
  let discoverySkillDirectoryURL =
    bundledSkillsDirectoryURL
    .appendingPathComponent("skills/supaterm", isDirectory: true)
  try FileManager.default.createDirectory(
    at: discoverySkillDirectoryURL.appendingPathComponent("agents", isDirectory: true),
    withIntermediateDirectories: true
  )
  try Data(
    skillDefinition(
      name: "supaterm",
      description: "Discover Supaterm skills.",
      title: "Supaterm",
      body: "Run `sp skills get core`."
    ).utf8
  ).write(to: discoverySkillDirectoryURL.appendingPathComponent("SKILL.md"))
  try Data("display_name: Supaterm\n".utf8)
    .write(to: discoverySkillDirectoryURL.appendingPathComponent("agents/openai.yaml"))

  let skillDataDirectoryURL = skillDataURL(bundledSkillsDirectoryURL)
  let coreDirectoryURL = skillDataDirectoryURL.appendingPathComponent("core", isDirectory: true)
  let referencesDirectoryURL = coreDirectoryURL.appendingPathComponent(
    "references", isDirectory: true)
  try FileManager.default.createDirectory(
    at: referencesDirectoryURL, withIntermediateDirectories: true)
  try Data(skillDefinition(name: "core", description: "Control Supaterm.", title: "Core").utf8)
    .write(to: coreDirectoryURL.appendingPathComponent("SKILL.md"))
  try Data("Tabs\n".utf8).write(to: referencesDirectoryURL.appendingPathComponent("tabs.md"))
  try Data("Panes\n".utf8).write(to: referencesDirectoryURL.appendingPathComponent("panes.md"))

  let agentsDirectoryURL = skillDataDirectoryURL.appendingPathComponent(
    "coding-agents",
    isDirectory: true
  )
  try FileManager.default.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true)
  try Data(
    skillDefinition(
      name: "coding-agents",
      description: "Launch coding agents.",
      title: "Coding Agents"
    ).utf8
  ).write(to: agentsDirectoryURL.appendingPathComponent("SKILL.md"))
  return bundledSkillsDirectoryURL
}

func skillDataURL(_ bundledSkillsDirectoryURL: URL) -> URL {
  bundledSkillsDirectoryURL.appendingPathComponent("skill-data", isDirectory: true)
}

func skillDefinition(
  name: String,
  description: String,
  title: String,
  body: String = ""
) -> String {
  """
  ---
  name: \(name)
  description: \(description)
  ---

  # \(title)

  \(body)
  """
}
