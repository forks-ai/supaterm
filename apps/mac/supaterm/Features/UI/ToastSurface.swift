import SwiftUI

public enum ToastSurfacePosition: Sendable {
  case topLeading
  case top
  case topTrailing
  case bottomLeading
  case bottom
  case bottomTrailing

  public var alignment: Alignment {
    switch self {
    case .topLeading:
      .topLeading
    case .top:
      .top
    case .topTrailing:
      .topTrailing
    case .bottomLeading:
      .bottomLeading
    case .bottom:
      .bottom
    case .bottomTrailing:
      .bottomTrailing
    }
  }
}

public struct ToastSurfaceAction: Identifiable {
  public let id: String
  public let title: String
  public let action: () -> Void

  public init(id: String, title: String, action: @escaping () -> Void) {
    self.id = id
    self.title = title
    self.action = action
  }
}

public struct ToastSurface<Accessory: View>: View {
  private let theme: SurfaceTheme
  private let title: String
  private let message: String?
  private let icon: String?
  private let tone: SurfaceTone
  private let actions: [ToastSurfaceAction]
  private let progress: Double?
  private let onDismiss: (() -> Void)?
  private let onHoverChange: (Bool) -> Void
  private let accessory: Accessory

  @State private var isHovering = false
  @Environment(\.colorScheme) private var colorScheme

  public init(
    theme: SurfaceTheme = .system,
    title: String,
    message: String? = nil,
    icon: String? = nil,
    tone: SurfaceTone = .neutral,
    actions: [ToastSurfaceAction] = [],
    progress: Double? = nil,
    onDismiss: (() -> Void)? = nil,
    onHoverChange: @escaping (Bool) -> Void = { _ in },
    @ViewBuilder accessory: () -> Accessory
  ) {
    self.theme = theme
    self.title = title
    self.message = message
    self.icon = icon
    self.tone = tone
    self.actions = actions
    self.progress = progress
    self.onDismiss = onDismiss
    self.onHoverChange = onHoverChange
    self.accessory = accessory()
  }

  public var body: some View {
    let colors = theme.colors(for: colorScheme)
    let toneColor = toneColor(colors: colors)

    SurfaceCard(
      theme: theme,
      style: SurfaceCardStyle(background: .material, corners: SurfaceCorners(13), shadowRadius: 14, shadowY: 6)
    ) {
      VStack(spacing: 0) {
        HStack(alignment: .top, spacing: 10) {
          Image(systemName: icon ?? defaultIcon)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(toneColor)
            .frame(width: 28, height: 28)
            .background(toneColor.opacity(0.14), in: .rect(cornerRadius: 8))
            .accessibilityHidden(true)

          VStack(alignment: .leading, spacing: 3) {
            Text(title)
              .font(.system(size: 13, weight: .semibold))
              .foregroundStyle(colors.primaryText)

            if let message {
              Text(message)
                .font(.system(size: 11))
                .foregroundStyle(colors.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
            }

            if !actions.isEmpty {
              HStack(spacing: 10) {
                ForEach(actions) { action in
                  Button(action.title, action: action.action)
                    .buttonStyle(.plain)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(colors.accent)
                }
              }
              .padding(.top, 5)
            }
          }

          Spacer(minLength: 8)

          accessory

          if let onDismiss {
            Button(action: onDismiss) {
              Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .frame(width: 18, height: 18)
                .background(colors.mutedBackground, in: .circle)
            }
            .buttonStyle(.plain)
            .foregroundStyle(colors.secondaryText)
            .opacity(isHovering ? 1 : 0.55)
            .accessibilityLabel("Dismiss notification")
          }
        }
        .padding(11)

        if let progress {
          GeometryReader { geometry in
            Capsule()
              .fill(toneColor)
              .frame(width: geometry.size.width * min(max(progress, 0), 1))
          }
          .frame(height: 2)
          .background(colors.mutedBackground)
        }
      }
    }
    .frame(minWidth: 260, maxWidth: 380)
    .onHover { hovering in
      isHovering = hovering
      onHoverChange(hovering)
    }
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("toast.surface")
  }

  private var defaultIcon: String {
    switch tone {
    case .neutral:
      "bell.fill"
    case .accent:
      "sparkles"
    case .success:
      "checkmark.circle.fill"
    case .warning:
      "exclamationmark.triangle.fill"
    case .danger:
      "xmark.octagon.fill"
    }
  }

  private func toneColor(colors: SurfaceColors) -> Color {
    switch tone {
    case .neutral:
      colors.secondaryText
    case .accent:
      colors.accent
    case .success:
      colors.success
    case .warning:
      colors.warning
    case .danger:
      colors.danger
    }
  }
}

extension ToastSurface where Accessory == EmptyView {
  public init(
    theme: SurfaceTheme = .system,
    title: String,
    message: String? = nil,
    icon: String? = nil,
    tone: SurfaceTone = .neutral,
    actions: [ToastSurfaceAction] = [],
    progress: Double? = nil,
    onDismiss: (() -> Void)? = nil,
    onHoverChange: @escaping (Bool) -> Void = { _ in }
  ) {
    self.init(
      theme: theme,
      title: title,
      message: message,
      icon: icon,
      tone: tone,
      actions: actions,
      progress: progress,
      onDismiss: onDismiss,
      onHoverChange: onHoverChange,
      accessory: { EmptyView() }
    )
  }
}

public struct ToastSurfaceOverlay<Content: View>: View {
  private let position: ToastSurfacePosition
  private let inset: CGFloat
  private let content: Content

  public init(
    position: ToastSurfacePosition = .bottomTrailing,
    inset: CGFloat = 16,
    @ViewBuilder content: () -> Content
  ) {
    self.position = position
    self.inset = inset
    self.content = content()
  }

  public var body: some View {
    content
      .padding(inset)
      .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
      .allowsHitTesting(true)
  }
}
