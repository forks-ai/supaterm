import AppKit
import ComposableArchitecture
import SupaTheme
import SupatermUpdateFeature
import SwiftUI

struct TerminalSplitView: View {
  let store: StoreOf<TerminalWindowFeature>
  let updateStore: StoreOf<UpdateFeature>
  let releaseAnnouncement: ReleaseAnnouncement?
  let palette: Palette
  let terminal: TerminalHostState
  let totalWidth: CGFloat
  let isSidebarCollapsed: Bool
  let sidebarWidth: CGFloat?
  let sidebarResizeState: TerminalSidebarResizeState?
  let onResizeInput: (TerminalSidebarResizeInput) -> Void
  let dismissReleaseAnnouncement: () -> Void

  var body: some View {
    let currentSidebarWidth = TerminalSidebarWidthPolicy.displayedWidth(
      preferredWidth: sidebarWidth,
      resizeState: sidebarResizeState,
      totalWidth: totalWidth
    )
    let visibleSidebarWidth = isSidebarCollapsed ? 0 : currentSidebarWidth

    ZStack(alignment: .leading) {
      HStack(spacing: 0) {
        TerminalSidebarView(
          store: store,
          updateStore: updateStore,
          releaseAnnouncement: releaseAnnouncement,
          palette: palette,
          terminal: terminal,
          isPagingActive: !isSidebarCollapsed,
          dismissReleaseAnnouncement: dismissReleaseAnnouncement
        )
        .frame(width: currentSidebarWidth)
        .frame(maxHeight: .infinity)
        .offset(x: isSidebarCollapsed ? -(currentSidebarWidth + 12) : 0)
        .frame(width: visibleSidebarWidth, alignment: .leading)
        .mask(alignment: .leading) {
          Rectangle()
            .padding(.trailing, -TerminalChromeMetrics.paneInset)
        }
        .allowsHitTesting(!isSidebarCollapsed)

        if let selectedTabID = terminal.selectedTabID {
          TerminalDetailView(
            store: store,
            palette: palette,
            terminal: terminal,
            selectedTabID: selectedTabID
          )
          .frame(maxWidth: .infinity, maxHeight: .infinity)
          .zIndex(1)
        } else {
          Color.clear
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      }

      if !isSidebarCollapsed {
        SidebarResizeHandle(onInput: onResizeInput)
          .offset(x: TerminalSplitMetrics.resizeStripOffset(for: currentSidebarWidth))
      }
    }
    .coordinateSpace(name: TerminalCoordinateSpace.split)
  }
}

struct TerminalSidebarView: View {
  let store: StoreOf<TerminalWindowFeature>
  let updateStore: StoreOf<UpdateFeature>
  let releaseAnnouncement: ReleaseAnnouncement?
  let palette: Palette
  let terminal: TerminalHostState
  let isPagingActive: Bool
  let dismissReleaseAnnouncement: () -> Void

  var body: some View {
    TerminalSidebarChromeView(
      store: store,
      updateStore: updateStore,
      releaseAnnouncement: releaseAnnouncement,
      palette: palette,
      terminal: terminal,
      isPagingActive: isPagingActive,
      fixedHoveredGroupID: nil,
      dismissReleaseAnnouncement: dismissReleaseAnnouncement
    )
    .overlay(alignment: .topLeading) {
      TerminalWindowHeader(
        store: store,
        palette: palette,
        terminal: terminal
      )
    }
    .padding(.bottom, sidebarBottomPadding)
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
  }
}

struct FloatingSidebarOverlay: View {
  let store: StoreOf<TerminalWindowFeature>
  let updateStore: StoreOf<UpdateFeature>
  let releaseAnnouncement: ReleaseAnnouncement?
  let palette: Palette
  let terminal: TerminalHostState
  let totalWidth: CGFloat
  let sidebarWidth: CGFloat?
  let sidebarResizeState: TerminalSidebarResizeState?
  @Binding var isVisible: Bool
  let onResizeInput: (TerminalSidebarResizeInput) -> Void
  let dismissReleaseAnnouncement: () -> Void

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var hidesAfterPaging = false

  var body: some View {
    let floatingWidth = TerminalSidebarWidthPolicy.displayedWidth(
      preferredWidth: sidebarWidth,
      resizeState: sidebarResizeState,
      totalWidth: totalWidth
    )

    ZStack(alignment: .leading) {
      if isVisible {
        FloatingSidebarView(
          store: store,
          updateStore: updateStore,
          releaseAnnouncement: releaseAnnouncement,
          palette: palette,
          terminal: terminal,
          width: floatingWidth,
          dismissReleaseAnnouncement: dismissReleaseAnnouncement
        )
        .frame(width: floatingWidth)
        .terminalTransition(.move(edge: .leading), reduceMotion: reduceMotion)
        .zIndex(1)
      }

      HStack(spacing: 0) {
        hoverStrip(width: isVisible ? floatingWidth : 10)
        Spacer(minLength: 0)
      }

      if isVisible {
        SidebarResizeHandle(onInput: onResizeInput)
          .offset(x: TerminalSplitMetrics.resizeStripOffset(for: floatingWidth))
          .zIndex(2)
      }
    }
    .coordinateSpace(name: TerminalCoordinateSpace.floatingSidebar)
    .onChange(of: isPaging) { _, isPaging in
      guard !isPaging, hidesAfterPaging else { return }
      hidesAfterPaging = false
      isVisible = false
    }
  }

  private var isPaging: Bool {
    terminal.spacePager?.isTracking == true
  }

  private var hoverBinding: Binding<Bool> {
    Binding(
      get: { isVisible },
      set: { hovering in
        guard !hovering, isPaging else {
          isVisible = hovering
          return
        }
        hidesAfterPaging = true
      }
    )
  }

  private func hoverStrip(width: CGFloat) -> some View {
    Color.clear
      .frame(width: width)
      .overlay {
        GlobalMouseTrackingArea(
          mouseEntered: hoverBinding,
          edge: .left,
          padding: 40,
          slack: 8
        )
      }
  }
}

private struct SidebarResizeHandle: View {
  let onInput: (TerminalSidebarResizeInput) -> Void

  var body: some View {
    SidebarResizeInteractionView(onInput: onInput)
      .frame(width: TerminalSidebarWidthPolicy.interactionStripWidth)
      .frame(maxHeight: .infinity)
  }
}

private struct SidebarResizeInteractionView: NSViewRepresentable {
  let onInput: (TerminalSidebarResizeInput) -> Void

  func makeNSView(context: Context) -> SidebarResizeInteractionNSView {
    let view = SidebarResizeInteractionNSView()
    update(view)
    return view
  }

  func updateNSView(_ nsView: SidebarResizeInteractionNSView, context: Context) {
    update(nsView)
  }

  private func update(_ view: SidebarResizeInteractionNSView) {
    view.onInput = onInput
  }
}

private final class SidebarResizeInteractionNSView: NSView {
  var onInput: ((TerminalSidebarResizeInput) -> Void)?
  private var trackingArea: NSTrackingArea?

  override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    let pan = NSPanGestureRecognizer(target: self, action: #selector(handlePan))
    let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(handleDoubleClick))
    doubleClick.numberOfClicksRequired = 2
    addGestureRecognizer(pan)
    addGestureRecognizer(doubleClick)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override var mouseDownCanMoveWindow: Bool {
    false
  }

  override func hitTest(_ point: NSPoint) -> NSView? {
    bounds.contains(point) ? self : nil
  }

  override func updateTrackingAreas() {
    if let trackingArea {
      removeTrackingArea(trackingArea)
    }
    let trackingArea = NSTrackingArea(
      rect: bounds,
      options: [.activeAlways, .cursorUpdate, .inVisibleRect],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(trackingArea)
    self.trackingArea = trackingArea
    window?.invalidateCursorRects(for: self)
    super.updateTrackingAreas()
  }

  override func resetCursorRects() {
    discardCursorRects()
    addCursorRect(bounds, cursor: .resizeLeftRight)
  }

  override func cursorUpdate(with event: NSEvent) {
    NSCursor.resizeLeftRight.set()
  }

  @objc private func handlePan(_ recognizer: NSPanGestureRecognizer) {
    switch recognizer.state {
    case .began:
      onInput?(.began)
      onInput?(.changed(delta: translationX(for: recognizer)))
    case .changed:
      onInput?(.changed(delta: translationX(for: recognizer)))
    case .ended:
      onInput?(.ended)
    case .cancelled, .failed:
      onInput?(.cancelled)
    default:
      break
    }
  }

  @objc private func handleDoubleClick(_ recognizer: NSClickGestureRecognizer) {
    guard recognizer.state == .ended else { return }
    onInput?(.doubleClicked)
  }

  private func translationX(for recognizer: NSPanGestureRecognizer) -> CGFloat {
    recognizer.translation(in: window?.contentView).x
  }
}

private struct FloatingSidebarView: View {
  let store: StoreOf<TerminalWindowFeature>
  let updateStore: StoreOf<UpdateFeature>
  let releaseAnnouncement: ReleaseAnnouncement?
  let palette: Palette
  let terminal: TerminalHostState
  let width: CGFloat
  let dismissReleaseAnnouncement: () -> Void

  var body: some View {
    TerminalSidebarView(
      store: store,
      updateStore: updateStore,
      releaseAnnouncement: releaseAnnouncement,
      palette: palette,
      terminal: terminal,
      isPagingActive: true,
      dismissReleaseAnnouncement: dismissReleaseAnnouncement
    )
    .frame(width: width)
    .background(palette.windowBackgroundTint)
    .background {
      BlurEffectView(material: .popover, blendingMode: .withinWindow)
    }
    .terminalPaneChrome(palette: palette)
    .shadow(color: palette.shadow, radius: 16, x: 0, y: 6)
  }
}

private let sidebarBottomPadding: CGFloat = 8
