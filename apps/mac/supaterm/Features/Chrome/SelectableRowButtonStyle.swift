import SupaTheme
import SwiftUI

struct SelectableRowButtonStyle: ButtonStyle {
  enum Appearance {
    case standard(restFill: Color)
    case sidebar(restFill: Color)

    func resolve(palette: Palette) -> ResolvedAppearance {
      switch self {
      case .standard(let restFill):
        ResolvedAppearance(
          selectedFill: palette.selectedFill,
          pressedFill: palette.pressedFill,
          hoverFill: palette.hoverFill,
          restFill: restFill,
          selectedStroke: AnyShapeStyle(palette.selectedStroke),
          selectedShadow: palette.selectedShadow
        )
      case .sidebar(let restFill):
        ResolvedAppearance(
          selectedFill: palette.sidebarSelectedFill,
          pressedFill: palette.sidebarItemPressedFill,
          hoverFill: palette.sidebarItemHoverFill,
          restFill: restFill,
          selectedStroke: AnyShapeStyle(palette.sidebarSelectedStroke),
          selectedShadow: palette.sidebarSelectedShadow
        )
      }
    }
  }

  struct ResolvedAppearance {
    let selectedFill: Color
    let pressedFill: Color
    let hoverFill: Color
    let restFill: Color
    let selectedStroke: AnyShapeStyle
    let selectedShadow: Color

    func fill(
      isSelected: Bool,
      isPressed: Bool,
      isHovering: Bool
    ) -> Color {
      if isSelected {
        return selectedFill
      }
      if isPressed {
        return pressedFill
      }
      if isHovering {
        return hoverFill
      }
      return restFill
    }
  }

  let palette: Palette
  let isSelected: Bool
  let isHovering: Bool
  let cornerRadius: CGFloat
  let appearance: Appearance
  let showsSelectionEdge: Bool
  let showsSelectionShadow: Bool

  init(
    palette: Palette,
    isSelected: Bool,
    isHovering: Bool,
    cornerRadius: CGFloat,
    appearance: Appearance = .standard(restFill: .clear),
    showsSelectionEdge: Bool = true,
    showsSelectionShadow: Bool = true
  ) {
    self.palette = palette
    self.isSelected = isSelected
    self.isHovering = isHovering
    self.cornerRadius = cornerRadius
    self.appearance = appearance
    self.showsSelectionEdge = showsSelectionEdge
    self.showsSelectionShadow = showsSelectionShadow
  }

  func makeBody(configuration: Configuration) -> some View {
    let resolvedAppearance = appearance.resolve(palette: palette)
    configuration.label
      .background(
        resolvedAppearance.fill(
          isSelected: isSelected,
          isPressed: configuration.isPressed,
          isHovering: isHovering
        )
      )
      .modifier(
        SelectableRowChrome(
          isSelected: isSelected,
          cornerRadius: cornerRadius,
          appearance: resolvedAppearance,
          showsSelectionEdge: showsSelectionEdge,
          showsSelectionShadow: showsSelectionShadow
        )
      )
  }
}

enum SelectableRowShadowMetrics {
  static let visualOutset: CGFloat = 30
  static let offset = CGSize(width: 0, height: 0.5)

  static func radius(isDark: Bool) -> CGFloat { isDark ? 15 : 12.5 }
}

struct SelectableRowChrome: ViewModifier {
  @Environment(\.colorScheme) private var colorScheme

  let isSelected: Bool
  let cornerRadius: CGFloat
  let appearance: SelectableRowButtonStyle.ResolvedAppearance
  let showsSelectionEdge: Bool
  let showsSelectionShadow: Bool

  init(
    isSelected: Bool,
    cornerRadius: CGFloat,
    appearance: SelectableRowButtonStyle.ResolvedAppearance,
    showsSelectionEdge: Bool,
    showsSelectionShadow: Bool = true
  ) {
    self.isSelected = isSelected
    self.cornerRadius = cornerRadius
    self.appearance = appearance
    self.showsSelectionEdge = showsSelectionEdge
    self.showsSelectionShadow = showsSelectionShadow
  }

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    let hasEdge = isSelected && showsSelectionEdge
    let hasShadow = hasEdge && showsSelectionShadow
    content
      .compositingGroup()
      .clipShape(shape)
      .overlay { selectionEdge(shape: shape, isVisible: hasEdge) }
      .shadow(
        color: hasShadow ? appearance.selectedShadow : .clear,
        radius: hasShadow ? SelectableRowShadowMetrics.radius(isDark: colorScheme == .dark) : 0,
        y: SelectableRowShadowMetrics.offset.height
      )
      .contentShape(shape)
  }

  @ViewBuilder
  private func selectionEdge(shape: RoundedRectangle, isVisible: Bool) -> some View {
    if isVisible {
      shape.strokeBorder(appearance.selectedStroke, lineWidth: 1)
    }
  }
}
