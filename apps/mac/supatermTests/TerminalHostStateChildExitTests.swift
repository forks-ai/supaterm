import Foundation
import GhosttyKit
import Synchronization
import Testing

@testable import supaterm

@MainActor
struct TerminalHostStateChildExitTests {
  @Test
  func childExitedRequestsImmediateCloseAndMarksActionHandled() async throws {
    initializeGhosttyForTests()

    let host = TerminalHostState()
    let stream = host.eventStream()
    var iterator = stream.makeAsyncIterator()
    host.ensureInitialTab(focusing: false, startupCommand: nil)

    let surface = try #require(host.selectedSurfaceView)
    let target = ghostty_target_s(tag: GHOSTTY_TARGET_SURFACE, target: ghostty_target_u())
    var action = ghostty_action_s(tag: GHOSTTY_ACTION_SHOW_CHILD_EXITED, action: ghostty_action_u())
    action.action.child_exited.exit_code = 0
    action.action.child_exited.timetime_ms = 28

    #expect(surface.bridge.handleAction(target: target, action: action))
    #expect(surface.bridge.state.childExitCode == 0)
    #expect(surface.bridge.state.childExitTimeMs == 28)

    let event = try #require(await iterator.next())
    #expect(event == .windowCloseRequested(needsConfirmation: false))
  }

  @Test
  func childExitRetriesAReportedZmxSessionBeforeClosing() async throws {
    initializeGhosttyForTests()
    let listedSessions = Mutex(0)
    let sessionID = Mutex<String?>(nil)
    let host = TerminalHostState(
      zmxClient: ZmxClient(
        executableURL: { nil },
        isBundled: { true },
        killSession: { _ in },
        listSessions: {
          listedSessions.withLock { count in
            count += 1
            return count == 1 ? sessionID.withLock { $0.map { [$0] } ?? [] } : []
          }
        }
      )
    )
    host.ensureInitialTab(focusing: false, startupCommand: nil)
    let surfaceID = try #require(host.selectedSurfaceView?.id)
    sessionID.withLock { $0 = ZmxSessionID.make(surfaceID: surfaceID) }

    host.requestCloseSurfaceAfterProcessExit(surfaceID, source: .ghosttyChildExit)

    for _ in 0..<100 {
      if listedSessions.withLock({ $0 }) == 2, !host.pendingEvents.isEmpty {
        break
      }
      try await Task.sleep(for: .milliseconds(10))
    }
    let event = try #require(host.pendingEvents.first)
    #expect(event == .windowCloseRequested(needsConfirmation: false))
    #expect(listedSessions.withLock { $0 } == 2)
  }

  @Test
  func childExitReattachesWhenZmxSessionRemainsAfterRetry() async throws {
    initializeGhosttyForTests()
    let listedSessions = Mutex(0)
    let sessionID = Mutex<String?>(nil)
    let host = TerminalHostState(
      zmxClient: ZmxClient(
        executableURL: { nil },
        isBundled: { true },
        killSession: { _ in },
        listSessions: {
          listedSessions.withLock { $0 += 1 }
          return sessionID.withLock { $0.map { [$0] } ?? [] }
        }
      )
    )
    host.ensureInitialTab(focusing: false, startupCommand: nil)
    let originalSurface = try #require(host.selectedSurfaceView)
    sessionID.withLock { $0 = ZmxSessionID.make(surfaceID: originalSurface.id) }

    host.requestCloseSurfaceAfterProcessExit(originalSurface.id, source: .ghosttyChildExit)

    for _ in 0..<100 {
      if listedSessions.withLock({ $0 }) >= 2,
        host.selectedSurfaceView !== originalSurface
      {
        break
      }
      try await Task.sleep(for: .milliseconds(10))
    }
    #expect(listedSessions.withLock { $0 } == 2)
    #expect(host.selectedSurfaceView?.id == originalSurface.id)
    #expect(host.selectedSurfaceView !== originalSurface)
  }
}
