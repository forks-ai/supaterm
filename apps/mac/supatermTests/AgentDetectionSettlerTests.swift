import Testing

@testable import SupatermSupport

struct AgentDetectionSettlerTests {
  @Test
  func initialNoMatchAndHoldStayUnknown() {
    let now = ContinuousClock().now
    var settler = AgentDetectionSettler<String>()

    #expect(settler.settle(match: .noMatch, processToken: "one", now: now) == .unknown)
    #expect(
      settler.settle(
        match: .matched(result: .hold, ruleID: "overlay", priority: 1),
        processToken: "one",
        now: now
      ) == .unknown
    )
  }

  @Test(arguments: [AgentDetectionRuleResult.running, .needsInput])
  func strongStatesPublishImmediately(result: AgentDetectionRuleResult) {
    let now = ContinuousClock().now
    var settler = AgentDetectionSettler<String>()

    let state = settler.settle(
      match: .matched(result: result, ruleID: "strong", priority: 1),
      processToken: "one",
      now: now
    )

    #expect(state == strongState(for: result))
  }

  @Test
  func initialIdlePublishesImmediately() {
    let now = ContinuousClock().now
    var settler = AgentDetectionSettler<String>()

    #expect(
      settler.settle(
        match: .matched(result: .idle, ruleID: "prompt", priority: 1),
        processToken: "one",
        now: now
      ) == .idle
    )
  }

  @Test
  func idleNeedsThreeConsecutiveMatchesAfterRunning() {
    let now = ContinuousClock().now
    var settler = AgentDetectionSettler<String>()
    let running = AgentDetectionMatch.matched(result: .running, ruleID: "working", priority: 2)
    let idle = AgentDetectionMatch.matched(result: .idle, ruleID: "prompt", priority: 1)

    #expect(settler.settle(match: running, processToken: "one", now: now) == .running)
    #expect(settler.settle(match: idle, processToken: "one", now: now) == .running)
    #expect(settler.settle(match: idle, processToken: "one", now: now) == .running)
    #expect(settler.settle(match: idle, processToken: "one", now: now) == .idle)
  }

  @Test
  func idlePublishesAtThe700MillisecondCap() {
    let now = ContinuousClock().now
    var settler = AgentDetectionSettler<String>()
    let running = AgentDetectionMatch.matched(result: .running, ruleID: "working", priority: 2)
    let idle = AgentDetectionMatch.matched(result: .idle, ruleID: "prompt", priority: 1)

    #expect(settler.settle(match: running, processToken: "one", now: now) == .running)
    #expect(settler.settle(match: idle, processToken: "one", now: now) == .running)
    #expect(
      settler.settle(
        match: idle,
        processToken: "one",
        now: now.advanced(by: .milliseconds(699))
      ) == .running
    )
    #expect(
      settler.settle(
        match: idle,
        processToken: "one",
        now: now.advanced(by: .milliseconds(700))
      ) == .idle
    )
  }

  @Test(arguments: [AgentDetectionRuleResult.running, .needsInput])
  func noMatchHoldsStrongStateForAtMost700Milliseconds(result: AgentDetectionRuleResult) {
    let now = ContinuousClock().now
    var settler = AgentDetectionSettler<String>()
    let strong = AgentDetectionMatch.matched(result: result, ruleID: "strong", priority: 1)

    let expectedState = strongState(for: result)
    #expect(settler.settle(match: strong, processToken: "one", now: now) == expectedState)
    #expect(settler.settle(match: .noMatch, processToken: "one", now: now) == expectedState)
    #expect(
      settler.settle(
        match: .noMatch,
        processToken: "one",
        now: now.advanced(by: .milliseconds(699))
      ) == expectedState
    )
    #expect(
      settler.settle(
        match: .noMatch,
        processToken: "one",
        now: now.advanced(by: .milliseconds(700))
      ) == .unknown
    )
  }

  @Test
  func noMatchAfterIdlePublishesUnknownImmediately() {
    let now = ContinuousClock().now
    var settler = AgentDetectionSettler<String>()
    let idle = AgentDetectionMatch.matched(result: .idle, ruleID: "prompt", priority: 1)

    #expect(settler.settle(match: idle, processToken: "one", now: now) == .idle)
    #expect(settler.settle(match: .noMatch, processToken: "one", now: now) == .unknown)
  }

  @Test
  func strongEvidenceCancelsPendingIdle() {
    let now = ContinuousClock().now
    var settler = AgentDetectionSettler<String>()
    let running = AgentDetectionMatch.matched(result: .running, ruleID: "working", priority: 2)
    let idle = AgentDetectionMatch.matched(result: .idle, ruleID: "prompt", priority: 1)

    _ = settler.settle(match: running, processToken: "one", now: now)
    _ = settler.settle(match: idle, processToken: "one", now: now)
    _ = settler.settle(match: idle, processToken: "one", now: now)
    _ = settler.settle(match: running, processToken: "one", now: now)
    #expect(settler.settle(match: idle, processToken: "one", now: now) == .running)
    #expect(settler.settle(match: idle, processToken: "one", now: now) == .running)
  }

  @Test
  func holdPreservesStateAndClearsPendingWork() {
    let now = ContinuousClock().now
    var settler = AgentDetectionSettler<String>()
    let running = AgentDetectionMatch.matched(result: .running, ruleID: "working", priority: 3)
    let idle = AgentDetectionMatch.matched(result: .idle, ruleID: "prompt", priority: 2)
    let hold = AgentDetectionMatch.matched(result: .hold, ruleID: "transcript", priority: 1)

    _ = settler.settle(match: running, processToken: "one", now: now)
    _ = settler.settle(match: idle, processToken: "one", now: now)
    _ = settler.settle(match: idle, processToken: "one", now: now)
    #expect(settler.settle(match: hold, processToken: "one", now: now) == .running)
    #expect(settler.settle(match: idle, processToken: "one", now: now) == .running)
    #expect(settler.settle(match: idle, processToken: "one", now: now) == .running)
  }

  @Test
  func processTokenChangeResetsBeforeApplyingEvidence() {
    let now = ContinuousClock().now
    var settler = AgentDetectionSettler<String>()
    let running = AgentDetectionMatch.matched(result: .running, ruleID: "working", priority: 1)
    let hold = AgentDetectionMatch.matched(result: .hold, ruleID: "overlay", priority: 1)

    #expect(settler.settle(match: running, processToken: "one", now: now) == .running)
    #expect(settler.settle(match: hold, processToken: "two", now: now) == .unknown)
    #expect(settler.settle(match: .noMatch, processToken: "two", now: now) == .unknown)
  }

  private func strongState(for result: AgentDetectionRuleResult) -> AgentDetectionState {
    switch result {
    case .running:
      .running
    case .needsInput:
      .needsInput
    case .idle, .hold:
      fatalError("Strong evidence requires a running or needs-input result")
    }
  }
}
