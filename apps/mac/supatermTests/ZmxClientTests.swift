import Foundation
import SupatermCLIShared
import Testing

@testable import SupatermSupport

struct ZmxClientTests {
  @Test
  func environmentDisablesSessions() {
    #expect(ZmxEnvironment.sessionsEnabled(setting: true, environment: [:]))
    #expect(!ZmxEnvironment.sessionsEnabled(setting: false, environment: [:]))
    #expect(
      !ZmxEnvironment.sessionsEnabled(
        setting: true,
        environment: [ZmxEnvironment.disabledKey: "1"]
      )
    )
  }

  @Test
  func sessionIDUsesInstanceNamespaceAndRoundTripsSurfaceID() {
    let surfaceID = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
    let environment = [SupatermCLIEnvironment.instanceNameKey: "dev/main"]
    let otherEnvironment = [SupatermCLIEnvironment.instanceNameKey: "dev-main"]
    let sessionID = ZmxSessionID.make(surfaceID: surfaceID, environment: environment)

    #expect(
      sessionID == "\(ZmxSessionID.namespacePrefix(environment: environment))01234567-89ab-cdef-0123-456789abcdef")
    #expect(ZmxSessionID.surfaceID(from: sessionID, environment: environment) == surfaceID)
    #expect(ZmxSessionID.surfaceID(from: sessionID, environment: otherEnvironment) == nil)
    #expect(ZmxSessionID.surfaceID(from: "other-01234567-89ab-cdef-0123-456789abcdef") == nil)
  }

  @Test
  func buildWrapperArgvKeepsExecutableAsOneArgument() {
    let argv = ZmxAttach.buildWrapperArgv(
      executablePath: "/Applications/Supaterm Runtime.app/Contents/Helpers/zmx",
      sessionID: "spt-session"
    )

    #expect(argv == ["/Applications/Supaterm Runtime.app/Contents/Helpers/zmx", "attach", "spt-session"])
  }

  @Test
  func socketBudgetUsesShortTemporaryDirectory() {
    #expect(ZmxSocketBudget.socketDir() == "/tmp/zmx-\(getuid())")
  }

  @Test
  func socketBudgetUsesConfiguredDirectory() {
    #expect(
      ZmxSocketBudget.socketDir(environment: [ZmxEnvironment.directoryKey: "/tmp/test-zmx"])
        == "/tmp/test-zmx"
    )
  }

  @Test
  func socketBudgetAcceptsShortTemporaryDirectory() {
    #expect(ZmxSocketBudget.probe() == nil)
  }
}
