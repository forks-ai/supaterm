import AppKit

@MainActor
final class TerminalSidebarPinnedControlHost {
  let view = TerminalSidebarPinnedControlView(frame: .zero)

  var height: CGFloat {
    view.isHidden ? 0 : TerminalSidebarLayout.pinnedControlHeight
  }

  init(
    draggingUpdated: @escaping (any NSDraggingInfo) -> NSDragOperation,
    draggingExited: @escaping () -> Void,
    draggingEnded: @escaping () -> Void,
    prepareForDragOperation: @escaping (any NSDraggingInfo) -> Bool,
    performDragOperation: @escaping (any NSDraggingInfo) -> Bool
  ) {
    view.isHidden = true
    view.onDraggingUpdated = draggingUpdated
    view.onDraggingExited = draggingExited
    view.onDraggingEnded = draggingEnded
    view.onPrepareForDragOperation = prepareForDragOperation
    view.onPerformDragOperation = performDragOperation
  }

  func update(context: TerminalSidebarRowContext) {
    view.isHidden = false
    view.host(TerminalSidebarHostedRow(presentation: .newTab, context: context))
  }

  func layout(in frame: CGRect) {
    view.frame = TerminalSidebarLayout.cardHorizontalInsets.frame(in: frame)
  }
}
