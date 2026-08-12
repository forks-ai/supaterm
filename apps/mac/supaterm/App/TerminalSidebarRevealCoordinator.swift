import CoreGraphics

enum TerminalSidebarRevealMetrics {
  static let activationWidth: CGFloat = 3.6
  static let activeOutsideWidth: CGFloat = 12
  static let activeWidth: CGFloat = 21
  static let lingerDuration = Duration.milliseconds(150)
  static let stoppedDuration = Duration.milliseconds(80)
  static let retentionWidth: CGFloat = 75

  static var activeInsideWidth: CGFloat {
    activeWidth - activeOutsideWidth
  }
}

enum TerminalSidebarRevealPointerEvent {
  case entered
  case exited
  case moved
}

@MainActor
final class TerminalSidebarRevealCoordinator {
  typealias Sleep = (Duration) async throws -> Void

  private(set) var isVisible = false
  var isPointerInside: () -> Bool = { false }
  var isRetained: () -> Bool = { false }
  var onVisibilityChange: (() -> Void)?
  private var lingerTask: Task<Void, Never>?
  private let sleep: Sleep
  private var stoppedTask: Task<Void, Never>?

  init(sleep: @escaping Sleep = { try await Task.sleep(for: $0) }) {
    self.sleep = sleep
  }

  func handle(_ event: TerminalSidebarRevealPointerEvent) {
    switch event {
    case .entered:
      guard !isVisible else { return }
      scheduleLinger()
      scheduleStopped()
    case .moved:
      guard !isVisible else { return }
      scheduleStopped()
    case .exited:
      cancelPendingReveal()
      guard isVisible, !isRetained() else { return }
      setVisible(false)
    }
  }

  func releaseRetention() {
    guard isVisible, !isPointerInside() else { return }
    setVisible(false)
  }

  func reset() {
    cancelPendingReveal()
    isVisible = false
  }

  private func scheduleLinger() {
    lingerTask?.cancel()
    lingerTask = revealTask(after: TerminalSidebarRevealMetrics.lingerDuration)
  }

  private func scheduleStopped() {
    stoppedTask?.cancel()
    stoppedTask = revealTask(after: TerminalSidebarRevealMetrics.stoppedDuration)
  }

  private func revealTask(after duration: Duration) -> Task<Void, Never> {
    Task { @MainActor [weak self, sleep] in
      do {
        try await sleep(duration)
      } catch {
        return
      }
      guard let self, !Task.isCancelled, self.isPointerInside() else { return }
      self.setVisible(true)
    }
  }

  private func setVisible(_ isVisible: Bool) {
    guard isVisible != self.isVisible else { return }
    cancelPendingReveal()
    self.isVisible = isVisible
    onVisibilityChange?()
  }

  private func cancelPendingReveal() {
    lingerTask?.cancel()
    lingerTask = nil
    stoppedTask?.cancel()
    stoppedTask = nil
  }

  isolated deinit {
    cancelPendingReveal()
  }
}
