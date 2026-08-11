import Foundation

@testable import supaterm

@MainActor
func fallbackObservation(
  in host: TerminalHostState,
  for surfaceID: UUID
) -> TerminalAgentDetectionObservation? {
  guard case .fallback(let observation, _) = host.resolvedAgentState(for: surfaceID).resolution
  else {
    return nil
  }
  return observation
}
