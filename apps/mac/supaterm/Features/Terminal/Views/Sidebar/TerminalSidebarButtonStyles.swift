import AppKit
import ComposableArchitecture
import Sharing
import SupatermCLIShared
import SupatermSupport
import SupatermUpdateFeature
import SwiftUI
import Textual

struct TerminalSidebarRectButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.isEnabled) private var isEnabled
  @State private var isHovering = false

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .background {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(.primary.opacity(backgroundOpacity(isPressed: configuration.isPressed)))
      }
      .contentShape(.rect)
      .opacity(isEnabled ? 1 : 0.3)
      .scaleEffect(configuration.isPressed && isEnabled ? 0.95 : 1)
      .terminalAnimation(
        .easeInOut(duration: 0.1),
        value: configuration.isPressed,
        reduceMotion: reduceMotion
      )
      .terminalAnimation(
        .easeInOut(duration: 0.15),
        value: isHovering,
        reduceMotion: reduceMotion
      )
      .onHover { isHovering = $0 }
  }

  private func backgroundOpacity(isPressed: Bool) -> Double {
    if (isHovering || isPressed) && isEnabled {
      return colorScheme == .dark ? 0.2 : 0.1
    }
    return 0
  }
}

struct TerminalSidebarIconButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.controlSize) private var controlSize
  @State private var isHovering = false

  func makeBody(configuration: Configuration) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.primary.opacity(backgroundOpacity(isPressed: configuration.isPressed)))
      configuration.label
    }
    .frame(width: size, height: size)
    .opacity(isEnabled ? 1 : 0.3)
    .contentShape(.rect)
    .scaleEffect(configuration.isPressed && isEnabled ? 0.95 : 1)
    .terminalAnimation(
      .easeInOut(duration: 0.1),
      value: configuration.isPressed,
      reduceMotion: reduceMotion
    )
    .terminalAnimation(
      .easeInOut(duration: 0.15),
      value: isHovering,
      reduceMotion: reduceMotion
    )
    .onHover { isHovering = $0 }
  }

  private var size: CGFloat {
    switch controlSize {
    case .mini: 24
    case .small: 28
    case .regular: 32
    case .large: 40
    case .extraLarge: 48
    @unknown default: 32
    }
  }

  private func backgroundOpacity(isPressed: Bool) -> Double {
    if (isHovering || isPressed) && isEnabled {
      return colorScheme == .dark ? 0.2 : 0.1
    }
    return 0
  }
}

struct TerminalSidebarSpaceButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  @Environment(\.colorScheme) private var colorScheme
  @Environment(\.isEnabled) private var isEnabled
  @Environment(\.controlSize) private var controlSize
  @State private var isHovering = false

  func makeBody(configuration: Configuration) -> some View {
    ZStack {
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(Color.primary.opacity(backgroundOpacity(isPressed: configuration.isPressed)))
      configuration.label
    }
    .frame(height: size)
    .frame(maxWidth: size)
    .opacity(isEnabled ? 1 : 0.3)
    .contentShape(.rect)
    .scaleEffect(configuration.isPressed && isEnabled ? 0.95 : 1)
    .terminalAnimation(
      .easeInOut(duration: 0.1),
      value: configuration.isPressed,
      reduceMotion: reduceMotion
    )
    .terminalAnimation(
      .easeInOut(duration: 0.15),
      value: isHovering,
      reduceMotion: reduceMotion
    )
    .onHover { isHovering = $0 }
  }

  private var size: CGFloat {
    switch controlSize {
    case .mini: 24
    case .small: 28
    case .regular: 32
    case .large: 40
    case .extraLarge: 48
    @unknown default: 32
    }
  }

  private func backgroundOpacity(isPressed: Bool) -> Double {
    if (isHovering || isPressed) && isEnabled {
      return colorScheme == .dark ? 0.2 : 0.1
    }
    return 0
  }
}
