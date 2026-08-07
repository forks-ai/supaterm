import SwiftUI

public struct PopoverSurfaceGeometry: Equatable, Sendable {
  public var size: CGSize
  public var offset: CGSize

  public init(size: CGSize, offset: CGSize = .zero) {
    self.size = size
    self.offset = offset
  }
}

public struct PopoverSurfaceLimits: Equatable, Sendable {
  public var minimumSize: CGSize
  public var maximumSize: CGSize

  public init(
    minimumSize: CGSize = CGSize(width: 220, height: 120),
    maximumSize: CGSize = CGSize(width: 900, height: 720)
  ) {
    self.minimumSize = minimumSize
    self.maximumSize = maximumSize
  }
}

enum PopoverSurfaceResizeHandle: CaseIterable, Sendable {
  case top
  case topTrailing
  case trailing
  case bottomTrailing
  case bottom
  case bottomLeading
  case leading
  case topLeading

  func resized(
    geometry: PopoverSurfaceGeometry,
    translation: CGSize,
    limits: PopoverSurfaceLimits
  ) -> PopoverSurfaceGeometry {
    let movesLeading = self == .leading || self == .topLeading || self == .bottomLeading
    let movesTrailing = self == .trailing || self == .topTrailing || self == .bottomTrailing
    let movesTop = self == .top || self == .topLeading || self == .topTrailing
    let movesBottom = self == .bottom || self == .bottomLeading || self == .bottomTrailing

    let proposedWidth =
      geometry.size.width
      + (movesLeading ? -translation.width : 0)
      + (movesTrailing ? translation.width : 0)
    let proposedHeight =
      geometry.size.height
      + (movesTop ? -translation.height : 0)
      + (movesBottom ? translation.height : 0)
    let width = min(max(proposedWidth, limits.minimumSize.width), limits.maximumSize.width)
    let height = min(max(proposedHeight, limits.minimumSize.height), limits.maximumSize.height)
    let widthChange = width - geometry.size.width
    let heightChange = height - geometry.size.height

    return PopoverSurfaceGeometry(
      size: CGSize(width: width, height: height),
      offset: CGSize(
        width: geometry.offset.width
          + (movesLeading ? -widthChange / 2 : 0)
          + (movesTrailing ? widthChange / 2 : 0),
        height: geometry.offset.height
          + (movesTop ? -heightChange / 2 : 0)
          + (movesBottom ? heightChange / 2 : 0)
      )
    )
  }
}

public struct PopoverSurface<Content: View>: View {
  private let theme: SurfaceTheme
  private let style: SurfaceCardStyle
  private let contentPadding: CGFloat
  private let size: CGSize?
  private let geometry: Binding<PopoverSurfaceGeometry>?
  private let limits: PopoverSurfaceLimits
  private let allowsMoving: Bool
  private let allowsResizing: Bool
  private let content: Content

  @State private var moveStart: PopoverSurfaceGeometry?
  @State private var resizeStart: PopoverSurfaceGeometry?

  public init(
    theme: SurfaceTheme = .system,
    style: SurfaceCardStyle = SurfaceCardStyle(background: .material),
    contentPadding: CGFloat = 12,
    size: CGSize? = nil,
    geometry: Binding<PopoverSurfaceGeometry>? = nil,
    limits: PopoverSurfaceLimits = PopoverSurfaceLimits(),
    allowsMoving: Bool = false,
    allowsResizing: Bool = false,
    @ViewBuilder content: () -> Content
  ) {
    self.theme = theme
    self.style = style
    self.contentPadding = contentPadding
    self.size = size
    self.geometry = geometry
    self.limits = limits
    self.allowsMoving = allowsMoving
    self.allowsResizing = allowsResizing
    self.content = content()
  }

  public var body: some View {
    SurfaceCard(theme: theme, style: style) {
      VStack(spacing: 0) {
        if geometry != nil && allowsMoving {
          moveHandle
        }

        content
          .frame(maxWidth: .infinity, alignment: .topLeading)
          .padding(contentPadding)
      }
      .frame(
        width: geometry?.wrappedValue.size.width ?? size?.width,
        height: geometry?.wrappedValue.size.height ?? size?.height,
        alignment: .topLeading
      )
    }
    .overlay {
      if geometry != nil && allowsResizing {
        resizeHandles
      }
    }
    .offset(geometry?.wrappedValue.offset ?? .zero)
    .accessibilityElement(children: .contain)
    .accessibilityIdentifier("popover.surface")
  }

  private var moveHandle: some View {
    Capsule()
      .fill(.secondary.opacity(0.4))
      .frame(width: 34, height: 4)
      .frame(maxWidth: .infinity)
      .padding(.top, 8)
      .padding(.bottom, 2)
      .contentShape(.rect)
      .gesture(
        DragGesture()
          .onChanged { value in
            guard let geometry else { return }
            let start = moveStart ?? geometry.wrappedValue
            moveStart = start
            geometry.wrappedValue.offset = CGSize(
              width: start.offset.width + value.translation.width,
              height: start.offset.height + value.translation.height
            )
          }
          .onEnded { _ in moveStart = nil }
      )
      .accessibilityLabel("Move popover")
  }

  private var resizeHandles: some View {
    ZStack {
      ForEach(PopoverSurfaceResizeHandle.allCases, id: \.self) { handle in
        Color.clear
          .frame(width: handleWidth(handle), height: handleHeight(handle))
          .contentShape(.rect)
          .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: alignment(handle))
          .gesture(resizeGesture(handle))
          .accessibilityLabel("Resize popover")
      }
    }
  }

  private func resizeGesture(_ handle: PopoverSurfaceResizeHandle) -> some Gesture {
    DragGesture()
      .onChanged { value in
        guard let geometry else { return }
        let start = resizeStart ?? geometry.wrappedValue
        resizeStart = start
        geometry.wrappedValue = handle.resized(
          geometry: start,
          translation: value.translation,
          limits: limits
        )
      }
      .onEnded { _ in resizeStart = nil }
  }

  private func alignment(_ handle: PopoverSurfaceResizeHandle) -> Alignment {
    switch handle {
    case .top:
      .top
    case .topTrailing:
      .topTrailing
    case .trailing:
      .trailing
    case .bottomTrailing:
      .bottomTrailing
    case .bottom:
      .bottom
    case .bottomLeading:
      .bottomLeading
    case .leading:
      .leading
    case .topLeading:
      .topLeading
    }
  }

  private func handleWidth(_ handle: PopoverSurfaceResizeHandle) -> CGFloat? {
    switch handle {
    case .top, .bottom:
      nil
    default:
      10
    }
  }

  private func handleHeight(_ handle: PopoverSurfaceResizeHandle) -> CGFloat? {
    switch handle {
    case .leading, .trailing:
      nil
    default:
      10
    }
  }
}
