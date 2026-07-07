import Foundation
import SupatermCLIShared
import Testing

struct SupatermSettingsCommandTests {
  @Test
  func registryListsEveryPublicConfigKey() {
    let result = SupatermSettingsRegistry.list(
      settings: .default,
      path: "/tmp/settings.toml",
      changedOnly: false
    )

    #expect(
      result.entries.map(\.key) == [
        "appearance.mode",
        "terminal.restore_layout",
        "terminal.confirm_quit",
        "terminal.zmx_sessions_enabled",
        "notifications.system_notifications",
        "notifications.glowing_pane_ring",
        "coding_agents.show_panel",
        "coding_agents.show_icons",
        "coding_agents.show_spinner",
        "privacy.analytics_enabled",
        "privacy.crash_reports_enabled",
        "updates.channel",
        "logging.verbose_enabled",
      ]
    )
    let allEntriesAreDefault = result.entries.allSatisfy { $0.isDefault }
    #expect(allEntriesAreDefault)
  }

  @Test
  func registrySetsAndResetsTypedValues() throws {
    let setEdit = try SupatermSettingsRegistry.set(
      SupatermSettingsSetRequest(key: "terminal.confirm_quit", value: "always"),
      settings: .default,
      path: "/tmp/settings.toml",
      isLive: true
    )

    #expect(setEdit.settings.confirmQuitMode == .always)
    #expect(setEdit.result.oldValue == "auto")
    #expect(setEdit.result.value == "always")
    #expect(!setEdit.result.isDefault)

    let resetEdit = try SupatermSettingsRegistry.reset(
      SupatermSettingsResetRequest(key: "terminal.confirm_quit"),
      settings: setEdit.settings,
      path: "/tmp/settings.toml",
      isLive: true
    )

    #expect(resetEdit.settings.confirmQuitMode == .auto)
    #expect(resetEdit.result.oldValue == "always")
    #expect(resetEdit.result.value == "auto")
    #expect(resetEdit.result.isDefault)
  }

  @Test
  func registryRejectsUnknownKeysAndInvalidValues() throws {
    do {
      _ = try SupatermSettingsRegistry.get(
        key: "terminal.unknown",
        settings: .default,
        path: "/tmp/settings.toml"
      )
      Issue.record("Expected unknown key to throw.")
    } catch let error as SupatermSettingsCommandError {
      #expect(error == .invalidKey("terminal.unknown"))
    } catch {
      Issue.record("Expected invalid key error, got \(error).")
    }

    do {
      _ = try SupatermSettingsRegistry.set(
        SupatermSettingsSetRequest(key: "appearance.mode", value: "sepia"),
        settings: .default,
        path: "/tmp/settings.toml",
        isLive: true
      )
      Issue.record("Expected invalid enum value to throw.")
    } catch let error as SupatermSettingsCommandError {
      #expect(
        error == .invalidValue(key: "appearance.mode", value: "sepia", allowedValues: ["system", "light", "dark"]))
    } catch {
      Issue.record("Expected invalid value error, got \(error).")
    }

    do {
      _ = try SupatermSettingsRegistry.set(
        SupatermSettingsSetRequest(key: "logging.verbose_enabled", value: "yes"),
        settings: .default,
        path: "/tmp/settings.toml",
        isLive: true
      )
      Issue.record("Expected invalid bool value to throw.")
    } catch let error as SupatermSettingsCommandError {
      #expect(error == .invalidValue(key: "logging.verbose_enabled", value: "yes", allowedValues: ["true", "false"]))
    } catch {
      Issue.record("Expected invalid boolean error, got \(error).")
    }
  }

  @Test
  func fileStoreCreatesSparseSettingsFile() throws {
    let stateHomeURL = try temporarySettingsCommandDirectory()
    let store = SupatermSettingsFileStore(environment: [SupatermCLIEnvironment.stateHomeKey: stateHomeURL.path])

    let result = try store.set(SupatermSettingsSetRequest(key: "logging.verbose_enabled", value: "true"))
    let contents = try String(contentsOf: store.settingsURL, encoding: .utf8).trimmingCharacters(in: .newlines)

    #expect(result.value == "true")
    #expect(result.warnings == ["Verbose logging changes apply next time Supaterm starts."])
    #expect(
      contents
        == """
        [logging]
        verbose_enabled = true
        """
    )
  }

  @Test
  func fileStoreResetRemovesDefaultOnlySections() throws {
    let stateHomeURL = try temporarySettingsCommandDirectory()
    let store = SupatermSettingsFileStore(environment: [SupatermCLIEnvironment.stateHomeKey: stateHomeURL.path])

    _ = try store.set(SupatermSettingsSetRequest(key: "updates.channel", value: "tip"))
    let result = try store.reset(SupatermSettingsResetRequest(key: "updates.channel"))
    let contents = try String(contentsOf: store.settingsURL, encoding: .utf8)

    #expect(result.oldValue == "tip")
    #expect(result.value == "stable")
    #expect(result.isDefault)
    #expect(contents.isEmpty)
  }

  @Test
  func fileStoreDoesNotRewriteInvalidToml() throws {
    let stateHomeURL = try temporarySettingsCommandDirectory()
    let store = SupatermSettingsFileStore(environment: [SupatermCLIEnvironment.stateHomeKey: stateHomeURL.path])
    try FileManager.default.createDirectory(at: stateHomeURL, withIntermediateDirectories: true)
    try Data("[updates]\nchannel = \"beta\"\n".utf8).write(to: store.settingsURL)

    do {
      _ = try store.set(SupatermSettingsSetRequest(key: "appearance.mode", value: "system"))
      Issue.record("Expected invalid existing TOML to throw.")
    } catch {
      let contents = try String(contentsOf: store.settingsURL, encoding: .utf8)
      #expect(contents == "[updates]\nchannel = \"beta\"\n")
    }
  }

  @Test
  func fileStoreChangedOnlyListOmitsDefaults() throws {
    let stateHomeURL = try temporarySettingsCommandDirectory()
    let store = SupatermSettingsFileStore(environment: [SupatermCLIEnvironment.stateHomeKey: stateHomeURL.path])

    _ = try store.set(SupatermSettingsSetRequest(key: "privacy.analytics_enabled", value: "false"))
    let result = try store.list(changedOnly: true)

    #expect(result.entries.map(\.key) == ["privacy.analytics_enabled"])
    #expect(result.entries.first?.value == "false")
  }
}

private func temporarySettingsCommandDirectory() throws -> URL {
  try FileManager.default.url(
    for: .itemReplacementDirectory,
    in: .userDomainMask,
    appropriateFor: FileManager.default.temporaryDirectory,
    create: true
  )
}
