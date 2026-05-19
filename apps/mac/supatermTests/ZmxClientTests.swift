import Foundation
import Testing

@testable import SupatermSupport

struct ZmxClientTests {
  @Test
  func sessionIDUsesSupatermPrefixAndRoundTripsSurfaceID() {
    let surfaceID = UUID(uuidString: "01234567-89AB-CDEF-0123-456789ABCDEF")!
    let sessionID = ZmxSessionID.make(surfaceID: surfaceID)

    #expect(sessionID == "spt-01234567-89ab-cdef-0123-456789abcdef")
    #expect(ZmxSessionID.surfaceID(from: sessionID) == surfaceID)
    #expect(ZmxSessionID.surfaceID(from: "other-01234567-89ab-cdef-0123-456789abcdef") == nil)
  }

  @Test
  func attachCommandQuotesExecutableAndUserCommand() {
    let command = ZmxAttach.buildCommand(
      executablePath: "/Applications/Supaterm's Runtime/zmx",
      sessionID: "spt-session",
      userCommand: "echo 'hello'"
    )

    #expect(command == #"'/Applications/Supaterm'\''s Runtime/zmx' attach spt-session /bin/sh -c 'echo '\''hello'\'''"#)
  }

  @Test
  func attachCommandOmitsEmptyUserCommand() {
    #expect(
      ZmxAttach.buildCommand(
        executablePath: "/tmp/zmx",
        sessionID: "spt-session",
        userCommand: "  "
      ) == "'/tmp/zmx' attach spt-session"
    )
  }

  @Test
  func socketBudgetMatchesZmxDirectoryPrecedenceAndTrimsSlashes() {
    #expect(
      ZmxSocketBudget.socketDir(
        environment: [
          "ZMX_DIR": "/custom/zmx",
          "XDG_RUNTIME_DIR": "/ignored",
        ]
      ) == "/custom/zmx"
    )
    #expect(ZmxSocketBudget.socketDir(environment: ["XDG_RUNTIME_DIR": "/run/user/501///"]) == "/run/user/501/zmx")
    #expect(ZmxSocketBudget.socketDir(environment: ["TMPDIR": "/tmp/app///"]).hasPrefix("/tmp/app/zmx-"))
  }

  @Test
  func socketBudgetRejectsOverlongDirectory() {
    let directory = "/" + String(repeating: "a", count: 98)

    #expect(ZmxSocketBudget.probe(environment: ["ZMX_DIR": directory]) != nil)
    #expect(ZmxSocketBudget.probe(environment: ["ZMX_DIR": "/tmp/zmx"]) == nil)
  }
}
