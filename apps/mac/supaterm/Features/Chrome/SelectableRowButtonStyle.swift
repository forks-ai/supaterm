import SupaTheme
import SwiftUI

enum SelectableRowSelection: Equatable {
  case none
  case primary
  case secondary
}

struct SelectableRowButtonStyle: ButtonStyle {
  enum Appearance {
    case standard(restFill: Color)
    case sidebar

    func resolve(palette: Palette) -> ResolvedAppearance {
      switch self {
      case .standard(let restFill):
        ResolvedAppearance(
          primarySelectionFill: palette.selectedFill,
          secondarySelectionFill: palette.selectedFill,
          pressedFill: palette.pressedFill,
          hoverFill: palette.hoverFill,
          restFill: restFill,
          selectedStroke: AnyShapeStyle(palette.selectedStroke),
          selectedShadow: palette.selectedShadow
        )
      case .sidebar:
        ResolvedAppearance(
          primarySelectionFill: palette.selectableRow.primarySelectionFill,
          secondarySelectionFill: palette.selectableRow.secondarySelectionFill,
          pressedFill: palette.selectableRow.pressedFill,
          hoverFill: palette.selectableRow.hoverFill,
          restFill: palette.selectableRow.restFill,
          selectedStroke: AnyShapeStyle(palette.sidebarTabRowSelectedEdge),
          selectedShadow: palette.selectableRow.shadow
        )
      }
    }
  }

  struct ResolvedAppearance {
    let primarySelectionFill: Color
    let secondarySelectionFill: Color
    let pressedFill: Color
    let hoverFill: Color
    let restFill: Color
    let selectedStroke: AnyShapeStyle
    let selectedShadow: Color

    func fill(
      selection: SelectableRowSelection,
      isPressed: Bool,
      isHovering: Bool
    ) -> Color {
      switch selection {
      case .primary:
        return primarySelectionFill
      case .secondary:
        return secondarySelectionFill
      case .none where isPressed:
        return pressedFill
      case .none where isHovering:
        return hoverFill
      case .none:
        return restFill
      }
    }
  }

  let palette: Palette
  let selection: SelectableRowSelection
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
    selection = isSelected ? .primary : .none
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
          selection: selection,
          isPressed: configuration.isPressed,
          isHovering: isHovering
        )
      )
      .modifier(
        SelectableRowChrome(
          selection: selection,
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

  let selection: SelectableRowSelection
  let cornerRadius: CGFloat
  let appearance: SelectableRowButtonStyle.ResolvedAppearance
  let showsSelectionEdge: Bool
  let showsSelectionShadow: Bool

  init(
    selection: SelectableRowSelection,
    cornerRadius: CGFloat,
    appearance: SelectableRowButtonStyle.ResolvedAppearance,
    showsSelectionEdge: Bool,
    showsSelectionShadow: Bool = true
  ) {
    self.selection = selection
    self.cornerRadius = cornerRadius
    self.appearance = appearance
    self.showsSelectionEdge = showsSelectionEdge
    self.showsSelectionShadow = showsSelectionShadow
  }

  func body(content: Content) -> some View {
    let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
    let hasEdge = selection == .primary && showsSelectionEdge
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
