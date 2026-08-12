import Clocks
import Testing

@testable import supaterm

@MainActor
struct TerminalSidebarRevealCoordinatorTests {
  @Test
  func stoppedPointerRevealsAfterStoppedDelay() async {
    let clock = TestClock()
    let coordinator = TerminalSidebarRevealCoordinator {
      try await clock.sleep(for: $0)
    }
    coordinator.isPointerInside = { true }

    coordinator.handle(.entered)
    await advanceClock(
      clock,
      by: TerminalSidebarRevealMetrics.stoppedDuration - .milliseconds(1)
    )
    #expect(!coordinator.isVisible)

    await advanceClock(clock, by: .milliseconds(1))
    #expect(coordinator.isVisible)
  }

  @Test
  func movingPointerKeepsLingerDeadlineAndResetsStoppedDelay() async {
    let clock = TestClock()
    let coordinator = TerminalSidebarRevealCoordinator {
      try await clock.sleep(for: $0)
    }
    coordinator.isPointerInside = { true }

    coordinator.handle(.entered)
    await advanceClock(clock, by: .milliseconds(70))
    coordinator.handle(.moved)
    await advanceClock(clock, by: .milliseconds(70))
    coordinator.handle(.moved)
    #expect(!coordinator.isVisible)

    await advanceClock(clock, by: .milliseconds(10))
    #expect(coordinator.isVisible)
  }

  @Test
  func exitingRevealRegionCancelsPendingReveal() async {
    let clock = TestClock()
    var isPointerInside = true
    let coordinator = TerminalSidebarRevealCoordinator {
      try await clock.sleep(for: $0)
    }
    coordinator.isPointerInside = { isPointerInside }

    coordinator.handle(.entered)
    await advanceClock(clock, by: .milliseconds(40))
    isPointerInside = false
    coordinator.handle(.exited)
    await advanceClock(clock, by: .milliseconds(200))

    #expect(!coordinator.isVisible)
  }

  @Test
  func releaseRetentionWaitsForEveryRetentionSource() async {
    let clock = TestClock()
    var isRetained = true
    let coordinator = TerminalSidebarRevealCoordinator {
      try await clock.sleep(for: $0)
    }
    coordinator.isPointerInside = { true }
    coordinator.isRetained = { isRetained }
    coordinator.handle(.entered)
    await advanceClock(clock, by: TerminalSidebarRevealMetrics.stoppedDuration)
    coordinator.isPointerInside = { false }

    coordinator.releaseRetention()
    #expect(coordinator.isVisible)

    isRetained = false
    coordinator.releaseRetention()
    #expect(!coordinator.isVisible)
  }
}
