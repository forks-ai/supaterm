import Foundation
import Sharing
import SupatermCLIShared

extension SharedKey where Self == FileStorageKey<SupatermSettings>.Default {
  public static var supatermSettings: Self {
    SupatermSettingsMigration.migrateDefaultSettingsIfNeeded()
    return Self[
      .fileStorage(
        SupatermStateRoot.settingsFileURL(),
        decode: SupatermSettingsCodec.decode,
        encode: SupatermSettingsCodec.encode
      ),
      default: .default
    ]
  }
}
