import SwiftUI
import Testing

@testable import supaterm

struct SplitViewTests {
  typealias TestSplitView = SplitView<EmptyView, EmptyView>

  @Test
  func dividerCursorsMatchTheirAxes() {
    #expect(TestSplitView.Direction.horizontal.dividerCursor == .columnResize)
    #expect(TestSplitView.Direction.vertical.dividerCursor == .rowResize)
  }
}
