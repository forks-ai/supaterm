import AppKit
import SupaTheme
import SwiftUI

enum TerminalSplitMetrics {
  nonisolated static let minimumPaneSize: CGFloat = 10
  nonisolated static let dividerVisibleSize: CGFloat = 1
  nonisolated static let dividerInvisibleSize: CGFloat = 6
  nonisolated static let dividerHitboxSize: CGFloat = dividerVisibleSize + dividerInvisibleSize
}

enum TerminalChromeMetrics {
  static let paneInset: CGFloat = 6
  static let paneCornerRadius: CGFloat = 16
  static var paneShape: RoundedRectangle {
    RoundedRectangle(cornerRadius: paneCornerRadius, style: .continuous)
  }

  static func nestedCornerRadius(
    inside outerCornerRadius: CGFloat,
    inset: CGFloat = paneInset
  ) -> CGFloat {
    Swift.max(0, outerCornerRadius - inset)
  }
}

enum TerminalFloatingSidebarShellMetrics {
  static let borderWidth: CGFloat = 1
  static let contentInset = TerminalChromeMetrics.paneInset
  static let cornerRadius = TerminalChromeMetrics.paneCornerRadius
  static let shadowRadius: CGFloat = 16
  static let shadowYOffset: CGFloat = 6
  static var shape: RoundedRectangle {
    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
  }
}

enum TerminalCoordinateSpace {
  static let split = "TerminalSplit"
  static let floatingSidebar = "TerminalFloatingSidebar"
}

private struct TerminalPaneSurfaceModifier: ViewModifier {
  let stroke: Color

  func body(content: Content) -> some View {
    content
      .clipShape(TerminalChromeMetrics.paneShape)
      .overlay {
        TerminalChromeMetrics.paneShape
          .stroke(stroke, lineWidth: 1)
      }
  }
}

struct TerminalFloatingSidebarShell<Content: View>: View {
  let palette: Palette
  let content: Content

  init(palette: Palette, @ViewBuilder content: () -> Content) {
    self.palette = palette
    self.content = content()
  }

  var body: some View {
    content
      .padding(TerminalFloatingSidebarShellMetrics.contentInset)
      .background {
        palette.windowBackgroundTint
          .background {
            BlurEffectView(material: .popover, blendingMode: .withinWindow)
          }
      }
      .compositingGroup()
      .clipShape(TerminalFloatingSidebarShellMetrics.shape)
      .overlay {
        TerminalFloatingSidebarShellMetrics.shape
          .stroke(palette.floatingSidebarBorder, lineWidth: TerminalFloatingSidebarShellMetrics.borderWidth)
      }
      .shadow(
        color: palette.shadow,
        radius: TerminalFloatingSidebarShellMetrics.shadowRadius,
        x: 0,
        y: TerminalFloatingSidebarShellMetrics.shadowYOffset
      )
  }
}

extension View {
  func terminalDetailPaneChrome(palette: Palette) -> some View {
    self
      .modifier(
        TerminalPaneSurfaceModifier(
          stroke: palette.colorScheme == .dark ? palette.detailStroke : .clear
        )
      )
      .shadow(color: palette.detailShadow, radius: 2, x: 0, y: 1)
      .padding(TerminalChromeMetrics.paneInset)
  }
}

struct ToolbarIconButton: View {
  let symbol: String
  let palette: Palette
  let accessibilityLabel: String?
  let showsAttentionIndicator: Bool
  let action: () -> Void

  @State private var isHovering = false

  init(
    symbol: String,
    palette: Palette,
    accessibilityLabel: String? = nil,
    showsAttentionIndicator: Bool = false,
    action: @escaping () -> Void = {}
  ) {
    self.symbol = symbol
    self.palette = palette
    self.accessibilityLabel = accessibilityLabel
    self.showsAttentionIndicator = showsAttentionIndicator
    self.action = action
  }

  var body: some View {
    Button(action: action) {
      ZStack(alignment: .topTrailing) {
        Image(systemName: symbol)
          .font(.system(size: 14, weight: .medium))
          .foregroundStyle(isHovering ? palette.secondaryText.opacity(0.8) : palette.secondaryText)

        if showsAttentionIndicator {
          Image(systemName: "circle.fill")
            .font(.system(size: 7, weight: .bold))
            .foregroundStyle(palette.warning)
            .background {
              Image(systemName: "circle.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(palette.detailBackground.opacity(0.9))
            }
            .offset(x: 3, y: -2)
            .accessibilityHidden(true)
        }
      }
      .frame(width: 30, height: 30)
      .background(
        isHovering ? palette.secondaryText.opacity(0.2) : .clear, in: .rect(cornerRadius: 6)
      )
      .accessibilityHidden(true)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(accessibilityLabel ?? "Action")
    .onHover { isHovering = $0 }
  }
}

enum WindowTrafficLightMetrics {
  static let buttonSize: CGFloat = 14
  static let buttonSpacing: CGFloat = 9
  static let edgePadding: CGFloat = 19
  static let symbolSize: CGFloat = 8

  static var clusterWidth: CGFloat {
    edgePadding + buttonSize * 3 + buttonSpacing * 2
  }
}

struct WindowTrafficLights: NSViewRepresentable {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeNSView(context: Context) -> WindowTrafficLightsView {
    WindowTrafficLightsView(reduceMotion: reduceMotion)
  }

  func updateNSView(_ nsView: WindowTrafficLightsView, context: Context) {
    nsView.reduceMotion = reduceMotion
  }
}

final class WindowTrafficLightsView: WindowDragSurfaceView {
  var reduceMotion: Bool

  private let buttons: [TrafficLightButton]

  init(reduceMotion: Bool) {
    self.reduceMotion = reduceMotion
    buttons = TrafficLight.allCases.map { TrafficLightButton(light: $0) }
    super.init(frame: .zero)
    buttons.forEach { addSubview($0) }
    addTrackingArea(
      NSTrackingArea(
        rect: .zero,
        options: [.activeInKeyWindow, .inVisibleRect, .mouseEnteredAndExited],
        owner: self
      )
    )
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override func layout() {
    super.layout()
    for (index, button) in buttons.enumerated() {
      button.frame = CGRect(
        x: WindowTrafficLightMetrics.edgePadding
          + CGFloat(index)
          * (WindowTrafficLightMetrics.buttonSize + WindowTrafficLightMetrics.buttonSpacing),
        y: bounds.height
          - WindowTrafficLightMetrics.edgePadding
          - WindowTrafficLightMetrics.buttonSize,
        width: WindowTrafficLightMetrics.buttonSize,
        height: WindowTrafficLightMetrics.buttonSize
      )
    }
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    guard bounds.contains(point) else { return nil }
    for button in buttons where button.frame.contains(point) {
      return button
    }
    return self
  }

  override func mouseEntered(with event: NSEvent) {
    setHovered(true)
  }

  override func mouseExited(with event: NSEvent) {
    setHovered(false)
  }

  private func setHovered(_ hovered: Bool) {
    NSAnimationContext.runAnimationGroup { context in
      context.duration = reduceMotion ? 0 : 0.1
      buttons.forEach { $0.setSymbolVisible(hovered) }
    }
  }
}

private final class TrafficLightButton: NSButton {
  private let light: TrafficLight
  private let symbolView: NSImageView

  init(light: TrafficLight) {
    self.light = light
    symbolView = NSImageView(
      image: NSImage(
        systemSymbolName: light.symbol,
        accessibilityDescription: nil
      ) ?? NSImage()
    )
    super.init(frame: .zero)
    isBordered = false
    wantsLayer = true
    layer?.backgroundColor = light.color.cgColor
    layer?.cornerRadius = WindowTrafficLightMetrics.buttonSize / 2
    symbolView.contentTintColor = .black.withAlphaComponent(0.55)
    symbolView.imageScaling = .scaleProportionallyDown
    symbolView.alphaValue = 0
    symbolView.setAccessibilityElement(false)
    addSubview(symbolView)
    target = self
    action = #selector(performAction)
    setAccessibilityLabel(light.accessibilityLabel)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  override func layout() {
    super.layout()
    symbolView.frame = bounds.insetBy(
      dx: (bounds.width - WindowTrafficLightMetrics.symbolSize) / 2,
      dy: (bounds.height - WindowTrafficLightMetrics.symbolSize) / 2
    )
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    bounds.contains(point) ? self : nil
  }

  func setSymbolVisible(_ visible: Bool) {
    symbolView.animator().alphaValue = visible ? 1 : 0
  }

  @objc private func performAction() {
    light.perform()
  }
}

private enum TrafficLight: CaseIterable {
  case close
  case minimize
  case zoom

  var color: NSColor {
    switch self {
    case .close:
      NSColor(red: 1, green: 0.37, blue: 0.34, alpha: 1)
    case .minimize:
      NSColor(red: 1, green: 0.74, blue: 0.18, alpha: 1)
    case .zoom:
      NSColor(red: 0.16, green: 0.8, blue: 0.33, alpha: 1)
    }
  }

  var symbol: String {
    switch self {
    case .close:
      "xmark"
    case .minimize:
      "minus"
    case .zoom:
      "plus"
    }
  }

  var accessibilityLabel: String {
    switch self {
    case .close:
      "Close window"
    case .minimize:
      "Minimize window"
    case .zoom:
      "Enter full screen"
    }
  }

  func perform() {
    guard let window = NSApp.keyWindow else { return }

    switch self {
    case .close:
      window.performClose(nil)
    case .minimize:
      window.performMiniaturize(nil)
    case .zoom:
      window.toggleFullScreen(nil)
    }
  }
}

struct WindowChromeConfigurator: NSViewRepresentable {
  func makeNSView(context: Context) -> WindowChromeConfiguratorView {
    WindowChromeConfiguratorView()
  }

  func updateNSView(_ nsView: WindowChromeConfiguratorView, context: Context) {
    nsView.applyWindowChrome()
  }
}

enum WindowChromeConfiguration {
  static func apply(to window: NSWindow) {
    window.titleVisibility = .hidden
    window.titlebarAppearsTransparent = true
    window.titlebarSeparatorStyle = .none
    window.toolbar = nil
    window.isMovableByWindowBackground = false
    window.standardWindowButton(.closeButton)?.isHidden = true
    window.standardWindowButton(.miniaturizeButton)?.isHidden = true
    window.standardWindowButton(.zoomButton)?.isHidden = true

    if let frameView = window.contentView?.superview,
      let titlebarContainer = firstDescendant(
        named: "NSTitlebarContainerView",
        in: frameView
      )
    {
      titlebarContainer.isHidden = true
    }
  }

  private static func firstDescendant(named className: String, in view: NSView) -> NSView? {
    for subview in view.subviews {
      if String(describing: type(of: subview)) == className {
        return subview
      }
      if let descendant = firstDescendant(named: className, in: subview) {
        return descendant
      }
    }
    return nil
  }
}

final class WindowChromeConfiguratorView: NSView {
  private let maxDeferredApplyCount = 2
  private var configuredWindowID: ObjectIdentifier?
  private var remainingDeferredApplies = 0

  override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    guard let window else {
      configuredWindowID = nil
      remainingDeferredApplies = 0
      return
    }
    let windowID = ObjectIdentifier(window)
    if configuredWindowID != windowID {
      configuredWindowID = windowID
      remainingDeferredApplies = maxDeferredApplyCount
    }
    applyWindowChrome()
  }

  func applyWindowChrome() {
    guard let window else { return }
    WindowChromeConfiguration.apply(to: window)
    scheduleDeferredApply(for: window)
  }

  private func scheduleDeferredApply(for window: NSWindow) {
    guard remainingDeferredApplies > 0 else { return }
    let windowID = ObjectIdentifier(window)
    remainingDeferredApplies -= 1
    DispatchQueue.main.async { [weak self] in
      guard let self, let window = self.window, ObjectIdentifier(window) == windowID else { return }
      WindowChromeConfiguration.apply(to: window)
      self.scheduleDeferredApply(for: window)
    }
  }
}
