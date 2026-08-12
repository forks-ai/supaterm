import AppKit

enum TerminalSidebarHoverCardPhase: Equatable {
  case idle
  case pending(TerminalTabID, UInt64)
  case presented(TerminalTabID)

  var tabID: TerminalTabID? {
    switch self {
    case .idle:
      nil
    case .pending(let tabID, _), .presented(let tabID):
      tabID
    }
  }

  var isPresented: Bool {
    switch self {
    case .presented:
      true
    case .idle, .pending:
      false
    }
  }
}

struct TerminalSidebarHoverCardGeometry {
  static let gap: CGFloat = 4
  static let screenInset: CGFloat = 8

  static func frame(
    sourceFrame: CGRect,
    cardSize: CGSize,
    visibleFrame: CGRect
  ) -> CGRect {
    let bounds = visibleFrame.insetBy(dx: screenInset, dy: screenInset)
    let maxX = max(bounds.minX, bounds.maxX - cardSize.width)
    let maxY = max(bounds.minY, bounds.maxY - cardSize.height)
    let origin = CGPoint(
      x: min(max(sourceFrame.maxX + gap, bounds.minX), maxX),
      y: min(max(sourceFrame.midY - cardSize.height / 2, bounds.minY), maxY)
    )
    return CGRect(origin: origin, size: cardSize)
  }

  @MainActor
  static func screenFrame(of view: NSView) -> CGRect? {
    guard let window = view.window, !view.bounds.isEmpty else { return nil }
    return window.convertToScreen(view.convert(view.bounds, to: nil))
  }

  static func isPointVisible(_ point: CGPoint, visibleRect: CGRect) -> Bool {
    visibleRect.contains(point)
  }
}

struct TerminalSidebarHoverCorridor {
  private let sourceFrame: CGRect
  private let cardFrame: CGRect

  init(sourceFrame: CGRect, cardFrame: CGRect) {
    self.sourceFrame = sourceFrame
    self.cardFrame = cardFrame.insetBy(dx: -2, dy: -2)
  }

  func contains(_ point: CGPoint) -> Bool {
    let points = Self.convexHull(
      Self.corners(of: sourceFrame) + Self.corners(of: cardFrame)
    )
    guard points.count >= 3 else { return false }
    var sign: CGFloat?
    for index in points.indices {
      let start = points[index]
      let end = points[
        points.index(after: index) == points.endIndex
          ? points.startIndex : points.index(after: index)]
      let cross = Self.cross(start, end, point)
      guard abs(cross) > Self.crossTolerance(start, end, point) else { continue }
      let currentSign: CGFloat = cross > 0 ? 1 : -1
      if let sign, sign != currentSign { return false }
      sign = currentSign
    }
    return true
  }

  func rayIntersectsCard(from origin: CGPoint, through point: CGPoint) -> Bool {
    let dx = point.x - origin.x
    let dy = point.y - origin.y
    let length = hypot(dx, dy)
    let end = CGPoint(x: point.x + dx / length * 1_000, y: point.y + dy / length * 1_000)
    return cardFrame.intersectsLine(from: point, to: end)
  }

  func containsSource(_ point: CGPoint) -> Bool {
    sourceFrame.containsClosed(point)
  }

  private static func corners(of rect: CGRect) -> [CGPoint] {
    [
      CGPoint(x: rect.minX, y: rect.minY),
      CGPoint(x: rect.maxX, y: rect.minY),
      CGPoint(x: rect.maxX, y: rect.maxY),
      CGPoint(x: rect.minX, y: rect.maxY),
    ]
  }

  private static func convexHull(_ points: [CGPoint]) -> [CGPoint] {
    let sorted = points.sorted {
      $0.x == $1.x ? $0.y < $1.y : $0.x < $1.x
    }
    guard sorted.count > 2 else { return sorted }
    var lower: [CGPoint] = []
    for point in sorted {
      while lower.count >= 2,
        cross(lower[lower.count - 2], lower[lower.count - 1], point) <= 0
      {
        lower.removeLast()
      }
      lower.append(point)
    }
    var upper: [CGPoint] = []
    for point in sorted.reversed() {
      while upper.count >= 2,
        cross(upper[upper.count - 2], upper[upper.count - 1], point) <= 0
      {
        upper.removeLast()
      }
      upper.append(point)
    }
    return Array(lower.dropLast() + upper.dropLast())
  }

  private static func cross(_ origin: CGPoint, _ first: CGPoint, _ second: CGPoint) -> CGFloat {
    (first.x - origin.x) * (second.y - origin.y)
      - (first.y - origin.y) * (second.x - origin.x)
  }

  private static func crossTolerance(
    _ origin: CGPoint,
    _ first: CGPoint,
    _ second: CGPoint
  ) -> CGFloat {
    let edgeScale = max(abs(first.x - origin.x), abs(first.y - origin.y), 1)
    let pointScale = max(abs(second.x - origin.x), abs(second.y - origin.y), 1)
    return 1e-9 * edgeScale * pointScale
  }
}

extension CGRect {
  func containsClosed(_ point: CGPoint) -> Bool {
    point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
  }

  fileprivate func intersectsLine(from start: CGPoint, to end: CGPoint) -> Bool {
    let delta = CGPoint(x: end.x - start.x, y: end.y - start.y)
    var lower: CGFloat = 0
    var upper: CGFloat = 1
    for (origin, distance, minimum, maximum) in [
      (start.x, delta.x, minX, maxX),
      (start.y, delta.y, minY, maxY),
    ] {
      if abs(distance) < 0.0001 {
        guard origin >= minimum, origin <= maximum else { return false }
        continue
      }
      let first = (minimum - origin) / distance
      let second = (maximum - origin) / distance
      lower = max(lower, min(first, second))
      upper = min(upper, max(first, second))
      guard lower <= upper else { return false }
    }
    return true
  }
}

struct TerminalSidebarHoverDirectionTracker {
  private enum State {
    case waiting
    case tracking(CGPoint)
    case decided(Bool)
  }

  private var state = State.waiting

  mutating func reset() {
    state = .waiting
  }

  mutating func permitsHull(at point: CGPoint, corridor: TerminalSidebarHoverCorridor) -> Bool {
    if corridor.containsSource(point) {
      reset()
      return true
    }
    switch state {
    case .waiting:
      state = .tracking(point)
      return true
    case .tracking(let origin):
      guard hypot(point.x - origin.x, point.y - origin.y) >= 8 else { return true }
      let permitsHull = corridor.rayIntersectsCard(from: origin, through: point)
      state = .decided(permitsHull)
      return permitsHull
    case .decided(let permitsHull):
      return permitsHull
    }
  }
}

enum TerminalSidebarHoverTiming {
  static let stopped = Duration.milliseconds(80)
  static let coldPresentation = Duration.milliseconds(250)
  static let dismiss = Duration.milliseconds(100)
}

enum TerminalSidebarHoverIntent: Equatable {
  case none
  case replacePending(TerminalTabID)
  case cancelPending
  case cancelDismiss
  case rearmDismiss
  case startCold(TerminalTabID)
  case reuse(TerminalTabID)
  case present(TerminalTabID)
  case update(TerminalTabID)
  case delayUpdate(TerminalTabID)
  case dismiss
}

enum TerminalSidebarHoverInteraction {
  static func eligibleTabID(
    pointedTabID: TerminalTabID?,
    screenPoint: CGPoint,
    cardFrame: CGRect?
  ) -> TerminalTabID? {
    cardFrame?.containsClosed(screenPoint) == true ? nil : pointedTabID
  }

  static func moved(
    phase: TerminalSidebarHoverCardPhase,
    eligibleTabID: TerminalTabID?,
    insideSafeHull: Bool
  ) -> TerminalSidebarHoverIntent {
    switch phase {
    case .idle:
      return .none
    case .pending(let currentTabID, _):
      guard let eligibleTabID else { return .cancelPending }
      return eligibleTabID == currentTabID ? .none : .replacePending(eligibleTabID)
    case .presented(let currentTabID):
      if insideSafeHull { return .cancelDismiss }
      guard let eligibleTabID else { return .rearmDismiss }
      return eligibleTabID == currentTabID ? .cancelDismiss : .update(eligibleTabID)
    }
  }

  static func stopped(
    phase: TerminalSidebarHoverCardPhase,
    eligibleTabID: TerminalTabID?,
    insideSafeHull: Bool,
    canReuseCard: Bool
  ) -> TerminalSidebarHoverIntent {
    switch phase {
    case .idle:
      guard let eligibleTabID else { return .none }
      return canReuseCard ? .reuse(eligibleTabID) : .startCold(eligibleTabID)
    case .pending:
      guard let eligibleTabID else { return .cancelPending }
      return .present(eligibleTabID)
    case .presented(let currentTabID):
      guard let eligibleTabID else { return insideSafeHull ? .cancelDismiss : .dismiss }
      guard eligibleTabID != currentTabID else { return .cancelDismiss }
      return insideSafeHull ? .delayUpdate(eligibleTabID) : .update(eligibleTabID)
    }
  }
}

enum TerminalSidebarHoverInputIntent: Equatable {
  case keep
  case dismiss(suppressedTabID: TerminalTabID?)
}

enum TerminalSidebarHoverInputInteraction {
  static func mouseDown(
    phase: TerminalSidebarHoverCardPhase,
    pointedTabID: TerminalTabID?,
    isInsideCard: Bool
  ) -> TerminalSidebarHoverInputIntent {
    if phase.isPresented, isInsideCard { return .keep }
    return .dismiss(suppressedTabID: pointedTabID)
  }
}

struct TerminalSidebarHoverTaskToken {
  private(set) var current: UInt64 = 0

  mutating func invalidate() {
    current &+= 1
  }

  func matches(_ candidate: UInt64) -> Bool {
    current == candidate
  }
}
