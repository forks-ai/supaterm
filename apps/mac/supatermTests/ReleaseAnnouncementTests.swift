import Testing

@testable import supaterm

struct ReleaseAnnouncementTests {
  @Test
  func semanticVersionComparesNumericComponents() throws {
    let lower = try #require(ReleaseAnnouncementVersion("1.3.2"))
    let higher = try #require(ReleaseAnnouncementVersion("1.3.10"))

    #expect(higher > lower)
  }

  @Test
  func equalVersionDoesNotShowAnnouncement() throws {
    let result = ReleaseAnnouncementCatalog.synchronize(
      currentVersion: "1.3.3",
      storageState: ReleaseAnnouncementStorageState(
        lastInstalledVersion: "1.3.3",
        acknowledgedVersion: "1.3.3"
      ),
      hasExistingSupatermState: true
    )

    #expect(result.announcement == nil)
    #expect(result.storageState.lastInstalledVersion == "1.3.3")
    #expect(result.storageState.acknowledgedVersion == "1.3.3")
  }

  @Test
  func malformedCurrentVersionHidesAnnouncement() {
    let stored = ReleaseAnnouncementStorageState(
      lastInstalledVersion: "1.3.2",
      acknowledgedVersion: "1.3.2"
    )
    let result = ReleaseAnnouncementCatalog.synchronize(
      currentVersion: "",
      storageState: stored,
      hasExistingSupatermState: true
    )

    #expect(result.announcement == nil)
    #expect(result.storageState == stored)
  }

  @Test
  func freshInstallSeedsCurrentVersionAndShowsNoHistoricalAnnouncement() {
    let result = ReleaseAnnouncementCatalog.synchronize(
      currentVersion: "1.3.3",
      storageState: nil,
      hasExistingSupatermState: false
    )

    #expect(result.announcement == nil)
    #expect(result.storageState.lastInstalledVersion == "1.3.3")
    #expect(result.storageState.acknowledgedVersion == "1.3.3")
  }

  @Test
  func existingInstallWithoutAnnouncementStateShowsCurrentCard() {
    let result = ReleaseAnnouncementCatalog.synchronize(
      currentVersion: "1.3.3",
      storageState: nil,
      hasExistingSupatermState: true
    )

    #expect(result.announcement == .terminalPersistence)
    #expect(result.storageState.lastInstalledVersion == "1.3.3")
    #expect(result.storageState.acknowledgedVersion == "1.3.2")
  }

  @Test
  func upgradeFromOlderAcknowledgedVersionShowsEligibleCard() {
    let result = ReleaseAnnouncementCatalog.synchronize(
      currentVersion: "1.3.3",
      storageState: ReleaseAnnouncementStorageState(
        lastInstalledVersion: "1.3.2",
        acknowledgedVersion: "1.3.2"
      ),
      hasExistingSupatermState: true
    )

    #expect(result.announcement == .terminalPersistence)
    #expect(result.storageState.lastInstalledVersion == "1.3.3")
    #expect(result.storageState.acknowledgedVersion == "1.3.2")
  }

  @Test
  func storedLastInstalledVersionDrivesAnnouncementWithoutAcknowledgedVersion() {
    let result = ReleaseAnnouncementCatalog.synchronize(
      currentVersion: "1.3.3",
      storageState: ReleaseAnnouncementStorageState(
        lastInstalledVersion: "1.3.2",
        acknowledgedVersion: nil
      ),
      hasExistingSupatermState: true
    )

    #expect(result.announcement == .terminalPersistence)
    #expect(result.storageState.lastInstalledVersion == "1.3.3")
    #expect(result.storageState.acknowledgedVersion == nil)
  }

  @Test
  func currentLastInstalledVersionHidesAnnouncementEvenWhenAcknowledgedVersionIsOlder() {
    let result = ReleaseAnnouncementCatalog.synchronize(
      currentVersion: "1.3.3",
      storageState: ReleaseAnnouncementStorageState(
        lastInstalledVersion: "1.3.3",
        acknowledgedVersion: "1.3.2"
      ),
      hasExistingSupatermState: true
    )

    #expect(result.announcement == nil)
    #expect(result.storageState.lastInstalledVersion == "1.3.3")
    #expect(result.storageState.acknowledgedVersion == "1.3.2")
  }

  @Test
  func terminalPersistenceCopyMatchesReleaseCard() {
    let expectedMessage = "Quit Supaterm anytime. Your agents, scripts, and shells keep running, "
      + "and reopen exactly where you left off."

    #expect(ReleaseAnnouncement.terminalPersistence.title == "Sessions persist across quits")
    #expect(
      ReleaseAnnouncement.terminalPersistence.message
        == expectedMessage
    )
    #expect(
      ReleaseAnnouncement.terminalPersistence.footer
        == "Manage in Settings → General"
    )
  }
}
