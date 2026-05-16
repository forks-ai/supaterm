import Foundation

nonisolated enum TerminalAgentPanelDiagnostics {
  nonisolated static func log(_ message: String) {
    print("[agent-panel] \(message)")
  }

  nonisolated static func surface(_ id: UUID) -> String {
    String(id.uuidString.prefix(8))
  }
}
