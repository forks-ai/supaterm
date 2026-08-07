import AppKit
import SupaTheme
import SwiftUI

public enum SurfaceTone: Sendable {
  case neutral
  case accent
  case warning
  case success
  case danger
}

public enum SurfaceTheme {
  case system
  case palette(Palette)

  func colors(for colorScheme: ColorScheme) -> SurfaceColors {
    switch self {
    case .system:
      SurfaceColors(
        background: Color(nsColor: .windowBackgroundColor),
        mutedBackground: Color.primary.opacity(0.08),
        hoverBackground: Color.primary.opacity(0.12),
        primaryText: .primary,
        secondaryText: .secondary,
        selectedText: colorScheme == .dark ? .black : .white,
        selectedBackground: Color.accentColor,
        border: Color.primary.opacity(colorScheme == .dark ? 0.18 : 0.12),
        divider: Color.primary.opacity(0.12),
        scrim: Color.black.opacity(0.4),
        shadow: Color.black.opacity(colorScheme == .dark ? 0.38 : 0.2),
        accent: .accentColor,
        onAccent: Color(nsColor: .selectedControlTextColor),
        warning: .orange,
        success: .green,
        danger: .red,
        dangerBackground: .red,
        dangerHoverBackground: Color.red.opacity(0.82),
        onDangerBackground: .white
      )
    case .palette(let palette):
      SurfaceColors(
        background: palette.selectedFill,
        mutedBackground: palette.selectedPillFill,
        hoverBackground: palette.hoverFill,
        primaryText: palette.selectedText,
        secondaryText: palette.selectedSecondaryText,
        selectedText: palette.selectedText,
        selectedBackground: palette.selectedPillFill,
        border: palette.selectedPillStroke,
        divider: palette.divider,
        scrim: palette.scrim,
        shadow: palette.overlayShadow,
        accent: palette.accent,
        onAccent: palette.onAccent,
        warning: palette.warning,
        success: palette.success,
        danger: palette.danger,
        dangerBackground: palette.dangerFill,
        dangerHoverBackground: palette.dangerHoverFill,
        onDangerBackground: palette.onDangerFill
      )
    }
  }
}

struct SurfaceColors {
  let background: Color
  let mutedBackground: Color
  let hoverBackground: Color
  let primaryText: Color
  let secondaryText: Color
  let selectedText: Color
  let selectedBackground: Color
  let border: Color
  let divider: Color
  let scrim: Color
  let shadow: Color
  let accent: Color
  let onAccent: Color
  let warning: Color
  let success: Color
  let danger: Color
  let dangerBackground: Color
  let dangerHoverBackground: Color
  let onDangerBackground: Color
}

public struct SurfaceCorners: Equatable, Sendable {
  public var topLeading: CGFloat
  public var bottomLeading: CGFloat
  public var bottomTrailing: CGFloat
  public var topTrailing: CGFloat

  public init(
    topLeading: CGFloat,
    bottomLeading: CGFloat,
    bottomTrailing: CGFloat,
    topTrailing: CGFloat
  ) {
    self.topLeading = topLeading
    self.bottomLeading = bottomLeading
    self.bottomTrailing = bottomTrailing
    self.topTrailing = topTrailing
  }

  public init(_ radius: CGFloat) {
    self.init(
      topLeading: radius,
      bottomLeading: radius,
      bottomTrailing: radius,
      topTrailing: radius
    )
  }

  var radii: RectangleCornerRadii {
    RectangleCornerRadii(
      topLeading: topLeading,
      bottomLeading: bottomLeading,
      bottomTrailing: bottomTrailing,
      topTrailing: topTrailing
    )
  }
}

public enum SurfaceBackground: Sendable {
  case solid
  case material
}

public struct SurfaceCardStyle: Sendable {
  public var background: SurfaceBackground
  public var corners: SurfaceCorners
  public var borderWidth: CGFloat
  public var shadowRadius: CGFloat
  public var shadowY: CGFloat

  public init(
    background: SurfaceBackground = .solid,
    corners: SurfaceCorners = SurfaceCorners(14),
    borderWidth: CGFloat = 0.5,
    shadowRadius: CGFloat = 20,
    shadowY: CGFloat = 8
  ) {
    self.background = background
    self.corners = corners
    self.borderWidth = borderWidth
    self.shadowRadius = shadowRadius
    self.shadowY = shadowY
  }
}

struct SurfaceCard<Content: View>: View {
  let theme: SurfaceTheme
  let style: SurfaceCardStyle
  @ViewBuilder let content: () -> Content

  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    let colors = theme.colors(for: colorScheme)
    let shape = UnevenRoundedRectangle(cornerRadii: style.corners.radii, style: .continuous)

    content()
      .background {
        switch style.background {
        case .solid:
          shape.fill(colors.background)
        case .material:
          shape.fill(.ultraThinMaterial)
            .overlay(shape.fill(colors.background.opacity(colorScheme == .dark ? 0.55 : 0.72)))
        }
      }
      .clipShape(shape)
      .overlay {
        shape.stroke(colors.border, lineWidth: style.borderWidth)
      }
      .shadow(color: colors.shadow, radius: style.shadowRadius, y: style.shadowY)
  }
}
