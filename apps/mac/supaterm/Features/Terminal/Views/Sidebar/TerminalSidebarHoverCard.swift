import AppKit
import Observation
import QuartzCore
import SupatermUI
import SwiftUI

struct TerminalSidebarHoverCardContent: Equatable {
  let tabTitle: String
  let agentName: String
  let response: String
}

enum TerminalSidebarHoverCardMetrics {
  static let width: CGFloat = 320
  static let horizontalPadding: CGFloat = 14
  static let maximumResponseHeight: CGFloat = 320

  @MainActor
  static func responseHeight(for response: AttributedString) -> CGFloat {
    let controller = NSHostingController(
      rootView: TerminalSidebarHoverCardResponseView(response: response)
    )
    let contentWidth = width - horizontalPadding * 2
    let height = controller.sizeThatFits(
      in: CGSize(width: contentWidth, height: maximumResponseHeight)
    ).height
    return min(max(ceil(height), 1), maximumResponseHeight)
  }
}

enum TerminalSidebarHoverCardPhase: Equatable {
  case idle
  case pending(TerminalTabID, UInt64)
  case presented(TerminalTabID)
  case tracking(TerminalTabID)

  var tabID: TerminalTabID? {
    switch self {
    case .idle:
      nil
    case .pending(let tabID, _), .presented(let tabID), .tracking(let tabID):
      tabID
    }
  }

  var isPresented: Bool {
    switch self {
    case .presented, .tracking:
      true
    case .idle, .pending:
      false
    }
  }
}

struct TerminalSidebarHoverCardGeometry: Equatable {
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
}

struct TerminalSidebarHoverCorridor: Equatable {
  private let points: [CGPoint]

  init(sourceFrame: CGRect, cardFrame: CGRect) {
    points = Self.convexHull(
      Self.corners(of: sourceFrame.insetBy(dx: -2, dy: -2))
        + Self.corners(of: cardFrame.insetBy(dx: -2, dy: -2))
    )
  }

  func contains(_ point: CGPoint) -> Bool {
    guard points.count >= 3 else { return false }
    var sign: CGFloat?
    for index in points.indices {
      let start = points[index]
      let end = points[points.index(after: index) == points.endIndex ? points.startIndex : points.index(after: index)]
      let cross = Self.cross(start, end, point)
      guard abs(cross) > .ulpOfOne else { continue }
      let currentSign: CGFloat = cross > 0 ? 1 : -1
      if let sign, sign != currentSign { return false }
      sign = currentSign
    }
    return true
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
}

@MainActor
final class TerminalSidebarHoverCardController {
  struct Source {
    let tabID: TerminalTabID
    let view: NSView
  }

  var presentationChanged: (() -> Void)?

  private(set) var phase = TerminalSidebarHoverCardPhase.idle
  private let sourceAtPoint: (CGPoint) -> Source?
  private let sourceForTab: (TerminalTabID) -> Source?
  private let content: (TerminalTabID) -> TerminalSidebarHoverCardContent?
  private let allowsPresentation: () -> Bool
  private let reduceMotion: () -> Bool
  private let presenter = TerminalSidebarHoverCardPresenter()
  private var generation: UInt64 = 0
  private var pendingTask: Task<Void, Never>?
  private var eventMonitor: Any?
  private var observers: [NSObjectProtocol] = []
  private var suppressedTabID: TerminalTabID?

  init(
    sourceAtPoint: @escaping (CGPoint) -> Source?,
    sourceForTab: @escaping (TerminalTabID) -> Source?,
    content: @escaping (TerminalTabID) -> TerminalSidebarHoverCardContent?,
    allowsPresentation: @escaping () -> Bool,
    reduceMotion: @escaping () -> Bool
  ) {
    self.sourceAtPoint = sourceAtPoint
    self.sourceForTab = sourceForTab
    self.content = content
    self.allowsPresentation = allowsPresentation
    self.reduceMotion = reduceMotion
  }

  isolated deinit {
    pendingTask?.cancel()
    removeEventMonitor()
    removeObservers()
  }

  var isPresented: Bool {
    phase.isPresented
  }

  func pointerMoved(to point: CGPoint?) {
    guard allowsPresentation() else {
      dismiss()
      return
    }
    if let point, let source = sourceAtPoint(point), content(source.tabID) != nil {
      guard source.tabID != suppressedTabID else { return }
      suppressedTabID = nil
      hover(source)
      return
    }
    suppressedTabID = nil
    trackPointer(at: NSEvent.mouseLocation)
  }

  func refresh() {
    guard let tabID = phase.tabID else { return }
    guard allowsPresentation(), let source = sourceForTab(tabID) else {
      dismiss()
      return
    }
    switch phase {
    case .idle:
      return
    case .pending:
      guard content(tabID) != nil else {
        dismiss()
        return
      }
    case .presented, .tracking:
      guard let content = observedContent(for: tabID) else {
        dismiss()
        return
      }
      presenter.update(
        content,
        sourceView: source.view,
        reduceMotion: reduceMotion()
      )
    }
  }

  func dismiss() {
    let wasPresented = phase.isPresented
    generation &+= 1
    pendingTask?.cancel()
    pendingTask = nil
    phase = .idle
    removeEventMonitor()
    removeObservers()
    presenter.dismiss(reduceMotion: reduceMotion())
    if wasPresented {
      presentationChanged?()
    }
  }

  private func hover(_ source: Source) {
    if phase.tabID == source.tabID {
      if phase.isPresented {
        phase = .presented(source.tabID)
      }
      return
    }
    schedulePresentation(for: source.tabID)
  }

  private func schedulePresentation(for tabID: TerminalTabID) {
    dismiss()
    generation &+= 1
    let generation = generation
    phase = .pending(tabID, generation)
    pendingTask = Task { [weak self] in
      do {
        try await Task.sleep(for: .milliseconds(250))
      } catch {
        return
      }
      guard let self else { return }
      present(tabID: tabID, generation: generation)
    }
  }

  private func present(tabID: TerminalTabID, generation: UInt64) {
    guard phase == .pending(tabID, generation), allowsPresentation(),
      let source = sourceForTab(tabID),
      let sourceWindow = source.view.window,
      sourceWindow.isKeyWindow,
      let content = observedContent(for: tabID)
    else {
      dismiss()
      return
    }
    guard
      presenter.present(
        content,
        sourceView: source.view,
        reduceMotion: reduceMotion()
      ) != nil
    else {
      dismiss()
      return
    }
    pendingTask = nil
    phase = .presented(tabID)
    installEventMonitor()
    observe(sourceWindow)
    presentationChanged?()
  }

  private func observedContent(for tabID: TerminalTabID) -> TerminalSidebarHoverCardContent? {
    withObservationTracking {
      content(tabID)
    } onChange: { [weak self] in
      Task { @MainActor [weak self] in
        self?.refresh()
      }
    }
  }

  private func trackPointer(at screenPoint: CGPoint) {
    guard let tabID = phase.tabID else { return }
    guard phase.isPresented else {
      dismiss()
      return
    }
    guard let source = sourceForTab(tabID), let sourceFrame = screenFrame(of: source.view),
      let cardFrame = presenter.frame
    else {
      dismiss()
      return
    }
    if sourceFrame.contains(screenPoint) || cardFrame.contains(screenPoint) {
      phase = .presented(tabID)
      return
    }
    if TerminalSidebarHoverCorridor(sourceFrame: sourceFrame, cardFrame: cardFrame)
      .contains(screenPoint)
    {
      phase = .tracking(tabID)
      return
    }
    dismiss()
  }

  private func installEventMonitor() {
    guard eventMonitor == nil else { return }
    eventMonitor = NSEvent.addLocalMonitorForEvents(
      matching: [
        .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged,
        .leftMouseDown, .rightMouseDown, .otherMouseDown, .keyDown,
      ]
    ) { [weak self] event in
      MainActor.assumeIsolated {
        self?.handle(event)
      }
      return event
    }
  }

  private func handle(_ event: NSEvent) {
    switch event.type {
    case .mouseMoved, .leftMouseDragged, .rightMouseDragged, .otherMouseDragged:
      trackPointer(at: screenPoint(for: event))
    case .leftMouseDown, .rightMouseDown, .otherMouseDown:
      let point = screenPoint(for: event)
      guard presenter.frame?.contains(point) == true else {
        suppressSource(at: point)
        dismiss()
        return
      }
    case .keyDown:
      dismiss()
    default:
      break
    }
  }

  private func suppressSource(at screenPoint: CGPoint) {
    guard let tabID = phase.tabID, let source = sourceForTab(tabID),
      screenFrame(of: source.view)?.contains(screenPoint) == true
    else { return }
    suppressedTabID = tabID
  }

  private func observe(_ sourceWindow: NSWindow) {
    removeObservers()
    let center = NotificationCenter.default
    observers = [
      center.addObserver(
        forName: NSWindow.didResignKeyNotification,
        object: sourceWindow,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.dismiss() }
      },
      center.addObserver(
        forName: NSWindow.willCloseNotification,
        object: sourceWindow,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.dismiss() }
      },
      center.addObserver(
        forName: NSApplication.didResignActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        MainActor.assumeIsolated { self?.dismiss() }
      },
    ]
  }

  private func removeEventMonitor() {
    guard let eventMonitor else { return }
    NSEvent.removeMonitor(eventMonitor)
    self.eventMonitor = nil
  }

  private func removeObservers() {
    for observer in observers {
      NotificationCenter.default.removeObserver(observer)
    }
    observers.removeAll()
  }

  private func screenFrame(of view: NSView) -> CGRect? {
    guard let window = view.window, !view.bounds.isEmpty else { return nil }
    return window.convertToScreen(view.convert(view.bounds, to: nil))
  }

  private func screenPoint(for event: NSEvent) -> CGPoint {
    guard let window = event.window else { return NSEvent.mouseLocation }
    return window.convertToScreen(CGRect(origin: event.locationInWindow, size: .zero)).origin
  }
}

@MainActor
private final class TerminalSidebarHoverCardPresenter {
  private let window = TerminalSidebarHoverCardWindow()
  private var hostingController: NSHostingController<TerminalSidebarHoverCardView>?
  private weak var parentWindow: NSWindow?
  private var animationGeneration: UInt64 = 0

  var frame: CGRect? {
    window.isVisible ? window.frame : nil
  }

  func present(
    _ content: TerminalSidebarHoverCardContent,
    sourceView: NSView,
    reduceMotion: Bool
  ) -> CGRect? {
    apply(
      content,
      sourceView: sourceView,
      reduceMotion: reduceMotion,
      animated: true
    )
  }

  func update(
    _ content: TerminalSidebarHoverCardContent,
    sourceView: NSView,
    reduceMotion: Bool
  ) {
    _ = apply(
      content,
      sourceView: sourceView,
      reduceMotion: reduceMotion,
      animated: false
    )
  }

  private func apply(
    _ content: TerminalSidebarHoverCardContent,
    sourceView: NSView,
    reduceMotion: Bool,
    animated: Bool
  ) -> CGRect? {
    guard let sourceWindow = sourceView.window else { return nil }
    animationGeneration &+= 1
    let rootView = TerminalSidebarHoverCardView(content: content)
    let hostingController: NSHostingController<TerminalSidebarHoverCardView>
    if let current = self.hostingController {
      current.rootView = rootView
      hostingController = current
    } else {
      let current = NSHostingController(rootView: rootView)
      current.view.wantsLayer = true
      window.contentViewController = current
      self.hostingController = current
      hostingController = current
    }
    let visibleFrame =
      sourceWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame
      ?? sourceWindow.frame
    let cardSize = hostingController.sizeThatFits(
      in: CGSize(
        width: TerminalSidebarHoverCardMetrics.width,
        height: max(120, visibleFrame.height - 16)
      )
    )
    guard let sourceFrame = screenFrame(of: sourceView), cardSize.width > 0, cardSize.height > 0
    else { return nil }
    let frame = TerminalSidebarHoverCardGeometry.frame(
      sourceFrame: sourceFrame,
      cardSize: cardSize,
      visibleFrame: visibleFrame
    )
    if parentWindow !== sourceWindow {
      parentWindow?.removeChildWindow(window)
      sourceWindow.addChildWindow(window, ordered: .above)
      parentWindow = sourceWindow
    }
    window.appearance = sourceWindow.appearance
    window.ignoresMouseEvents = false
    window.setFrame(frame, display: false)
    window.orderFront(nil)
    show(reduceMotion: reduceMotion, animated: animated)
    return frame
  }

  func dismiss(reduceMotion: Bool) {
    guard window.isVisible else { return }
    animationGeneration &+= 1
    let generation = animationGeneration
    guard !reduceMotion, let layer = hostingController?.view.layer else {
      close()
      return
    }
    window.ignoresMouseEvents = true
    layer.removeAllAnimations()
    let opacity = layer.presentation()?.opacity ?? layer.opacity
    let scale = layer.presentation()?.value(forKeyPath: "transform.scale") as? CGFloat ?? 1
    CATransaction.begin()
    CATransaction.setCompletionBlock { [weak self] in
      Task { @MainActor [weak self] in
        guard let self, animationGeneration == generation else { return }
        close()
      }
    }
    layer.opacity = 0
    layer.setValue(0.92, forKeyPath: "transform.scale")
    layer.add(
      TerminalLayerAnimation.basic(
        keyPath: "opacity",
        from: opacity,
        to: 0,
        duration: 0.1,
        timingFunction: CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
      ),
      forKey: "sidebarHoverCardOpacity"
    )
    layer.add(
      TerminalLayerAnimation.spring(
        keyPath: "transform.scale",
        from: scale,
        to: 0.92,
        spring: TerminalLayerSpring(response: 0.2, dampingRatio: 0.6)
      ),
      forKey: "sidebarHoverCardScale"
    )
    CATransaction.commit()
  }

  private func show(reduceMotion: Bool, animated: Bool) {
    guard let layer = hostingController?.view.layer else { return }
    layer.removeAllAnimations()
    layer.opacity = 1
    layer.setValue(1, forKeyPath: "transform.scale")
    guard animated, !reduceMotion else { return }
    layer.add(
      TerminalLayerAnimation.basic(
        keyPath: "opacity",
        from: 0,
        to: 1,
        duration: 0.1,
        timingFunction: CAMediaTimingFunction(controlPoints: 0.25, 0.46, 0.45, 0.94)
      ),
      forKey: "sidebarHoverCardOpacity"
    )
    layer.add(
      TerminalLayerAnimation.spring(
        keyPath: "transform.scale",
        from: 0.92,
        to: 1,
        spring: TerminalLayerSpring(response: 0.25, dampingRatio: 0.75)
      ),
      forKey: "sidebarHoverCardScale"
    )
  }

  private func close() {
    hostingController?.view.layer?.removeAllAnimations()
    parentWindow?.removeChildWindow(window)
    window.orderOut(nil)
    window.ignoresMouseEvents = false
    parentWindow = nil
  }

  private func screenFrame(of view: NSView) -> CGRect? {
    guard let window = view.window, !view.bounds.isEmpty else { return nil }
    return window.convertToScreen(view.convert(view.bounds, to: nil))
  }
}

@MainActor
private final class TerminalSidebarHoverCardWindow: NSWindow {
  init() {
    super.init(
      contentRect: .zero,
      styleMask: .borderless,
      backing: .buffered,
      defer: false
    )
    isOpaque = false
    backgroundColor = .clear
    hasShadow = true
    isReleasedWhenClosed = false
    acceptsMouseMovedEvents = true
    collectionBehavior = [.transient, .ignoresCycle]
  }

  override var canBecomeKey: Bool { false }
  override var canBecomeMain: Bool { false }
}

struct TerminalSidebarHoverCardView: View {
  private let tabTitle: String
  private let agentName: String
  private let response: AttributedString
  private let responseHeight: CGFloat

  @MainActor
  init(content: TerminalSidebarHoverCardContent) {
    tabTitle = content.tabTitle
    agentName = content.agentName
    let response =
      (try? AttributedString(markdown: content.response)) ?? AttributedString(content.response)
    self.response = response
    responseHeight = TerminalSidebarHoverCardMetrics.responseHeight(for: response)
  }

  var body: some View {
    PopoverSurface(
      theme: .system,
      style: SurfaceCardStyle(
        background: .material,
        corners: SurfaceCorners(10),
        borderWidth: 0.5,
        shadowRadius: 0,
        shadowY: 0
      ),
      contentPadding: 0
    ) {
      VStack(alignment: .leading, spacing: 10) {
        VStack(alignment: .leading, spacing: 1) {
          Text(tabTitle)
            .font(.system(size: 13, weight: .medium))
            .lineLimit(2)
          Text("\(agentName) · Latest response")
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            .lineLimit(1)
        }
        Divider()
        ScrollView {
          TerminalSidebarHoverCardResponseView(response: response)
        }
        .frame(height: responseHeight)
      }
      .padding(.horizontal, TerminalSidebarHoverCardMetrics.horizontalPadding)
      .padding(.vertical, 16)
      .frame(width: TerminalSidebarHoverCardMetrics.width, alignment: .leading)
    }
    .accessibilityLabel("Latest agent response for \(tabTitle)")
  }
}

private struct TerminalSidebarHoverCardResponseView: View {
  let response: AttributedString

  var body: some View {
    Text(response)
      .font(.system(size: 13))
      .frame(maxWidth: .infinity, alignment: .leading)
      .fixedSize(horizontal: false, vertical: true)
      .textSelection(.enabled)
  }
}
