import AppKit
import SwiftUI

@MainActor
final class TerminalSidebarCollectionItem: NSCollectionViewItem {
  static let identifier = NSUserInterfaceItemIdentifier("TerminalSidebarCollectionItem")
  private let containerView = TerminalSidebarHostingContainerView()

  override func loadView() {
    view = containerView
  }

  func host(
    _ view: TerminalSidebarHostedRow,
    entryID: TerminalSidebarEntryID
  ) {
    containerView.host(view, entryID: entryID)
  }

  func liftHostedView(sourceFrame: CGRect) -> TerminalSidebarLiftedRow? {
    guard let hostedView = containerView.liftHostedView() else { return nil }
    return TerminalSidebarLiftedRow(
      hostedView: hostedView,
      sourceFrame: sourceFrame,
      restore: { [weak self, weak hostedView] in
        guard let self, let hostedView else { return }
        restoreHostedView(hostedView)
      }
    )
  }

  func restoreHostedView(_ hostedView: NSView) {
    containerView.restoreHostedView(hostedView)
  }
}

@MainActor
struct TerminalSidebarLiftedRow {
  let hostedView: NSView
  let sourceFrame: CGRect
  let restoreAction: @MainActor () -> Void

  init(
    hostedView: NSView,
    sourceFrame: CGRect,
    restore: @escaping @MainActor () -> Void
  ) {
    self.hostedView = hostedView
    self.sourceFrame = sourceFrame
    restoreAction = restore
  }

  func restore() {
    restoreAction()
  }
}

@MainActor
final class TerminalSidebarHostingContainerView: NSView {
  private var hostingView: NSHostingView<TerminalSidebarHostedRow>?
  private var entryID: TerminalSidebarEntryID?
  private var isLifted = false

  override func layout() {
    super.layout()
    if !isLifted { hostingView?.frame = bounds }
  }

  func pointerEntry(at windowPoint: NSPoint) -> TerminalSidebarEntryID? {
    let point = convert(windowPoint, from: nil)
    guard
      bounds.contains(point),
      point.x < bounds.maxX - 30,
      let hostingView,
      routesPointerEvents(for: hostingView.rootView),
      let entryID
    else { return nil }
    return entryID
  }

  private func routesPointerEvents(for row: TerminalSidebarHostedRow) -> Bool {
    switch row.presentation {
    case .tab:
      true
    case .group(let presentation):
      row.context.renameState.groupID != presentation.id
    case .pinDivider, .newTab:
      false
    }
  }

  func host(
    _ rootView: TerminalSidebarHostedRow,
    entryID: TerminalSidebarEntryID
  ) {
    self.entryID = entryID
    if let hostingView {
      hostingView.rootView = rootView
      if !isLifted { hostingView.frame = bounds }
      return
    }
    let hostingView = NSHostingView(rootView: rootView)
    hostingView.frame = bounds
    hostingView.autoresizingMask = [.width, .height]
    addSubview(hostingView)
    self.hostingView = hostingView
  }

  func liftHostedView() -> NSView? {
    guard let hostingView, !isLifted else { return nil }
    isLifted = true
    hostingView.removeFromSuperview()
    return hostingView
  }

  func restoreHostedView(_ hostedView: NSView) {
    guard hostedView === hostingView else { return }
    hostedView.removeFromSuperview()
    addSubview(hostedView)
    hostedView.frame = bounds
    isLifted = false
  }
}
