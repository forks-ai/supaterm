import SupaTheme
import SwiftUI

struct GhosttySurfaceHoverLinkOverlay: View {
  let link: String
  let palette: Palette

  @State private var pointerIsNearLeadingBanner = false

  var body: some View {
    GhosttySurfaceHoverLinkPresentation(
      link: link,
      palette: palette,
      pointerIsNearLeadingBanner: pointerIsNearLeadingBanner,
      onLeadingBannerHoverChange: { pointerIsNearLeadingBanner = $0 }
    )
  }
}

struct GhosttySurfaceHoverLinkPresentation: View {
  enum Placement: Equatable {
    case leading
    case trailing
  }

  let link: String
  let palette: Palette
  let pointerIsNearLeadingBanner: Bool
  let onLeadingBannerHoverChange: (Bool) -> Void

  private let padding: CGFloat = 6
  private let cornerRadius: CGFloat = 9

  var body: some View {
    let placement = Self.placement(pointerIsNearLeadingBanner: pointerIsNearLeadingBanner)
    ZStack {
      banner(placement: .trailing, onHover: { _ in })
        .opacity(placement == .trailing ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(placement != .trailing)

      banner(placement: .leading, onHover: onLeadingBannerHoverChange)
        .opacity(placement == .leading ? 1 : 0)
        .accessibilityHidden(placement != .leading)
    }
  }

  static func placement(pointerIsNearLeadingBanner: Bool) -> Placement {
    pointerIsNearLeadingBanner ? .trailing : .leading
  }

  private func banner(
    placement: Placement,
    onHover: @escaping (Bool) -> Void
  ) -> some View {
    HStack(spacing: 0) {
      if placement == .trailing {
        Spacer(minLength: 0)
      }

      Text(verbatim: link)
        .font(.callout)
        .foregroundStyle(palette.primaryText)
        .lineLimit(1)
        .truncationMode(.middle)
        .padding(padding)
        .background(palette.detailBackground, in: shape(for: placement))
        .overlay {
          shape(for: placement)
            .strokeBorder(palette.detailStroke, lineWidth: 1)
        }
        .shadow(color: palette.overlayShadow, radius: 6, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hovered link")
        .accessibilityValue(link)
        .accessibilityIdentifier("terminal-hovered-link")
        .onHover(perform: onHover)

      if placement == .leading {
        Spacer(minLength: 0)
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
  }

  private func shape(for placement: Placement) -> UnevenRoundedRectangle {
    UnevenRoundedRectangle(
      cornerRadii: RectangleCornerRadii(
        topLeading: placement == .trailing ? cornerRadius : 0,
        topTrailing: placement == .leading ? cornerRadius : 0
      ),
      style: .continuous
    )
  }
}
