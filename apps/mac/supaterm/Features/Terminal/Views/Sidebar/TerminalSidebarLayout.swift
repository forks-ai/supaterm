import CoreGraphics
import Foundation

enum TerminalSidebarLayout {
  struct HorizontalInsets {
    let leading: CGFloat
    let trailing: CGFloat

    func inset(by value: CGFloat) -> Self {
      Self(
        leading: leading + value,
        trailing: trailing + value
      )
    }

    func width(in containerWidth: CGFloat) -> CGFloat {
      max(1, containerWidth - leading - trailing)
    }

    func frame(in bounds: CGRect) -> CGRect {
      CGRect(
        x: bounds.minX + leading,
        y: bounds.minY,
        width: width(in: bounds.width),
        height: bounds.height
      )
    }
  }

  static let groupCornerRadius: CGFloat = 12
  static let tabRowCornerRadius: CGFloat = 8
  static let tabRowMinHeight: CGFloat = 30
  static let rowHorizontalPadding: CGFloat = 10
  static let visibleHorizontalInset: CGFloat = 10
  static let groupedTabHorizontalInset: CGFloat = 6
  static var cardHorizontalInsets: HorizontalInsets {
    HorizontalInsets(
      leading: visibleHorizontalInset,
      trailing: visibleHorizontalInset - TerminalChromeMetrics.paneInset
    )
  }
  static var groupedTabHorizontalInsets: HorizontalInsets {
    cardHorizontalInsets.inset(by: groupedTabHorizontalInset)
  }
  static let tabRowVerticalPadding: CGFloat = 5
  static let tabRowSpacing: CGFloat = 2
  static let cardCornerRadius: CGFloat = 12
  static let cardMinHeight: CGFloat = 36
  static let cardVerticalPadding: CGFloat = 8
  static let trafficLightTopPadding: CGFloat = 6

  static var firstVisibleSectionTopInset: CGFloat {
    trafficLightTopPadding + WindowTrafficLightMetrics.topPadding + WindowTrafficLightMetrics.buttonSize + 4
  }

  static func spaceMonogram(
    for name: String,
    fallbackIndex: Int
  ) -> String {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    if let first = trimmed.first {
      return String(first).uppercased()
    }
    return String(fallbackIndex + 1)
  }

  static func showsSpaceList(
    spacesCount: Int
  ) -> Bool {
    spacesCount > 1
  }

}
