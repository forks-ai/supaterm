import AppKit
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
    GeometryReader { geometry in
      let placement = Self.placement(pointerIsNearLeadingBanner: pointerIsNearLeadingBanner)
      let maximumBannerWidth = Self.maximumBannerWidth(containerWidth: geometry.size.width)
      ZStack {
        banner(placement: .trailing, maximumWidth: maximumBannerWidth)
          .opacity(placement == .trailing ? 1 : 0)
          .accessibilityHidden(placement != .trailing)

        banner(placement: .leading, maximumWidth: maximumBannerWidth)
          .opacity(placement == .leading ? 1 : 0)
          .accessibilityHidden(placement != .leading)
      }
    }
  }

  static func placement(pointerIsNearLeadingBanner: Bool) -> Placement {
    pointerIsNearLeadingBanner ? .trailing : .leading
  }

  static func maximumBannerWidth(containerWidth: CGFloat) -> CGFloat {
    max(0, containerWidth * 0.45)
  }

  private func banner(
    placement: Placement,
    maximumWidth: CGFloat
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
        .frame(maxWidth: maximumWidth)
        .background(palette.detailBackground, in: shape(for: placement))
        .background {
          if placement == .leading {
            GhosttySurfaceHoverTrackingView(onHoverChange: onLeadingBannerHoverChange)
          }
        }
        .overlay {
          shape(for: placement)
            .strokeBorder(palette.detailStroke, lineWidth: 1)
        }
        .shadow(color: palette.overlayShadow, radius: 6, y: 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hovered link")
        .accessibilityValue(link)
        .accessibilityIdentifier("terminal-hovered-link")
        .allowsHitTesting(false)

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

struct GhosttySurfaceHoverTrackingView: NSViewRepresentable {
  let onHoverChange: (Bool) -> Void

  func makeNSView(context: Context) -> TrackingView {
    TrackingView(onHoverChange: onHoverChange)
  }

  func updateNSView(_ nsView: TrackingView, context: Context) {
    nsView.onHoverChange = onHoverChange
  }

  final class TrackingView: NSView {
    var onHoverChange: (Bool) -> Void

    init(onHoverChange: @escaping (Bool) -> Void) {
      self.onHoverChange = onHoverChange
      super.init(frame: .zero)
      addTrackingArea(
        NSTrackingArea(
          rect: .zero,
          options: [.mouseEnteredAndExited, .activeInActiveApp, .inVisibleRect],
          owner: self
        )
      )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
      nil
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
      nil
    }

    override func mouseEntered(with event: NSEvent) {
      onHoverChange(true)
    }

    override func mouseExited(with event: NSEvent) {
      onHoverChange(false)
    }
  }
}
