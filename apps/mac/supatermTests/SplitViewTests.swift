import SwiftUI
import Testing

@testable import supaterm

struct SplitViewTests {
  typealias TestSplitView = SplitView<EmptyView, EmptyView>

  @Test
  func dividerCursorsMatchTheirAxes() {
    #expect(
      String(reflecting: TestSplitView.Direction.horizontal.dividerPointerStyle)
        == String(reflecting: PointerStyle.columnResize))
    #expect(
      String(reflecting: TestSplitView.Direction.vertical.dividerPointerStyle)
        == String(reflecting: PointerStyle.rowResize))
  }
}
