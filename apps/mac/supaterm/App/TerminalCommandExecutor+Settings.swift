import Foundation
import Sharing
import SupatermCLIShared
import SupatermSupport

@MainActor
extension TerminalCommandExecutor {
  func settingsList(_ request: SupatermSettingsListRequest) -> SupatermSettingsListResult {
    @Shared(.supatermSettings) var supatermSettings = SupatermSettings.default
    return SupatermSettingsRegistry.list(
      settings: supatermSettings,
      path: SupatermSettings.defaultURL().path,
      changedOnly: request.changedOnly
    )
  }

  func settingsGet(_ request: SupatermSettingsGetRequest) throws -> SupatermSettingsGetResult {
    @Shared(.supatermSettings) var supatermSettings = SupatermSettings.default
    return try SupatermSettingsRegistry.get(
      key: request.key,
      settings: supatermSettings,
      path: SupatermSettings.defaultURL().path
    )
  }

  func settingsSet(_ request: SupatermSettingsSetRequest) throws -> SupatermSettingsMutationResult {
    @Shared(.supatermSettings) var supatermSettings = SupatermSettings.default
    let edit = try SupatermSettingsRegistry.set(
      request,
      settings: supatermSettings,
      path: SupatermSettings.defaultURL().path,
      isLive: true
    )
    $supatermSettings.withLock {
      $0 = edit.settings
    }
    applySettingsSideEffects(key: try SupatermSettingsKey(path: request.key), settings: edit.settings)
    return edit.result
  }

  func settingsReset(_ request: SupatermSettingsResetRequest) throws -> SupatermSettingsMutationResult {
    @Shared(.supatermSettings) var supatermSettings = SupatermSettings.default
    let edit = try SupatermSettingsRegistry.reset(
      request,
      settings: supatermSettings,
      path: SupatermSettings.defaultURL().path,
      isLive: true
    )
    $supatermSettings.withLock {
      $0 = edit.settings
    }
    applySettingsSideEffects(key: try SupatermSettingsKey(path: request.key), settings: edit.settings)
    return edit.result
  }

  private func applySettingsSideEffects(
    key: SupatermSettingsKey,
    settings: SupatermSettings
  ) {
    switch key {
    case .loggingVerboseEnabled:
      SupatermLog.setVerboseLoggingEnabled(settings.verboseLoggingEnabled)
    case .updatesChannel:
      registry.setUpdateChannel(settings.updateChannel)
    default:
      break
    }
  }
}
