import SwiftUI

struct TerminalSidebarTabTitlePresentation: Equatable {
  let tabID: TerminalTabID
  let title: String
  let isTitleLocked: Bool

  func shouldType(
    from previous: Self,
    reduceMotion: Bool
  ) -> Bool {
    !reduceMotion
      && tabID == previous.tabID
      && title != previous.title
      && isTitleLocked
  }

  static func typingFrames(for title: String) -> [String] {
    let characters = Array(title)
    let frameCount = min(characters.count, 16)
    guard frameCount > 0 else { return [] }
    return (1...frameCount).map { frame in
      String(characters.prefix(frame * characters.count / frameCount))
    }
  }
}

struct TerminalSidebarTabTitleView: View {
  let presentation: TerminalSidebarTabTitlePresentation

  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @State private var typedTitle: String?
  @State private var typingTarget: String?

  var body: some View {
    Text(typedTitle ?? presentation.title)
      .accessibilityLabel(presentation.title)
      .onChange(of: presentation) { previous, current in
        guard current.shouldType(from: previous, reduceMotion: reduceMotion) else {
          typedTitle = nil
          typingTarget = nil
          return
        }
        typedTitle = ""
        typingTarget = current.title
      }
      .onChange(of: reduceMotion) {
        guard reduceMotion else { return }
        typedTitle = nil
        typingTarget = nil
      }
      .task(id: typingTarget) {
        guard let target = typingTarget else { return }
        do {
          for frame in TerminalSidebarTabTitlePresentation.typingFrames(for: target) {
            try await ContinuousClock().sleep(for: .milliseconds(24))
            typedTitle = frame
          }
        } catch {
          return
        }
        typedTitle = nil
        typingTarget = nil
      }
  }
}
