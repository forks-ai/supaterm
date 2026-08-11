public enum AgentDetectionState: Equatable, Sendable {
  case unknown
  case running
  case needsInput
  case idle
}

public struct AgentDetectionSettler<ProcessToken: Hashable & Sendable>: Sendable {
  private var processToken: ProcessToken?
  private var state = AgentDetectionState.unknown
  private var pending: Pending?

  public init() {}

  public mutating func settle(
    match: AgentDetectionMatch,
    processToken: ProcessToken,
    now: ContinuousClock.Instant
  ) -> AgentDetectionState {
    if self.processToken != processToken {
      self.processToken = processToken
      state = .unknown
      pending = nil
    }

    switch match {
    case .matched(.running, _, _):
      return publish(.running)
    case .matched(.needsInput, _, _):
      return publish(.needsInput)
    case .matched(.hold, _, _):
      pending = nil
      return state
    case .matched(.idle, _, _):
      return settleIdle(now: now)
    case .noMatch:
      return settleNoMatch(now: now)
    }
  }

  private mutating func settleIdle(now: ContinuousClock.Instant) -> AgentDetectionState {
    guard state.isStrong else { return publish(.idle) }
    let count: Int
    let startedAt: ContinuousClock.Instant
    if case .idle(let existingCount, let existingStart) = pending {
      count = existingCount + 1
      startedAt = existingStart
    } else {
      count = 1
      startedAt = now
    }
    if count >= 3 || startedAt.duration(to: now) >= .milliseconds(700) {
      return publish(.idle)
    }
    pending = .idle(count: count, startedAt: startedAt)
    return state
  }

  private mutating func settleNoMatch(now: ContinuousClock.Instant) -> AgentDetectionState {
    guard state.isStrong else { return publish(.unknown) }
    let startedAt: ContinuousClock.Instant
    if case .noMatch(let existingStart) = pending {
      startedAt = existingStart
    } else {
      startedAt = now
    }
    if startedAt.duration(to: now) >= .milliseconds(700) {
      return publish(.unknown)
    }
    pending = .noMatch(startedAt: startedAt)
    return state
  }

  private mutating func publish(_ state: AgentDetectionState) -> AgentDetectionState {
    self.state = state
    pending = nil
    return state
  }

  private enum Pending: Sendable {
    case idle(count: Int, startedAt: ContinuousClock.Instant)
    case noMatch(startedAt: ContinuousClock.Instant)
  }
}

extension AgentDetectionState {
  fileprivate var isStrong: Bool {
    self == .running || self == .needsInput
  }
}
