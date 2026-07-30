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
  static let tabTrailingAccessorySize: CGFloat = 24
  static let rowHorizontalPadding: CGFloat = 10
  static let visibleHorizontalInset: CGFloat = 10
  static let groupedTabHorizontalInset: CGFloat = 6
  static var cardHorizontalInsets: HorizontalInsets {
    HorizontalInsets(
      leading: visibleHorizontalInset,
      trailing: visibleHorizontalInset
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
  static let groupSurfaceOverflow: CGFloat = 2
  static let trafficLightGap: CGFloat = 6

  static var scrollViewportTopInset: CGFloat {
    WindowTrafficLightMetrics.edgePadding
      + WindowTrafficLightMetrics.buttonSize
      + trafficLightGap
  }

  static func scrollViewportFrame(in bounds: CGRect) -> CGRect {
    CGRect(
      x: bounds.minX,
      y: bounds.minY,
      width: bounds.width,
      height: max(0, bounds.height - scrollViewportTopInset)
    )
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

}
