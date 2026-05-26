import ComposableArchitecture
import SupatermSupport

extension SettingsFeature {
  func reduceAdvanced(_ state: inout State, action: Action) -> Effect<Action> {
    switch action {
    case .verboseLoggingEnabledChanged(let isEnabled):
      state.verboseLoggingEnabled = isEnabled
      SupatermLog.setVerboseLoggingEnabled(isEnabled)
      return persist(state)

    default:
      return .none
    }
  }
}
