import AppKit
import SwiftUI

struct Palette {
  private let colorScheme: ColorScheme

  private var isDark: Bool { colorScheme == .dark }
  private var primary: Color { Color(.displayP3, red: 0.89, green: 0.902, blue: 0.925) }

  var backgroundTop: Color { isDark ? Color(rgb: 0x1F1F1F) : Color(rgb: 0xE4E4E4) }
  var backgroundBottom: Color { isDark ? Color(rgb: 0x191919) : Color(rgb: 0xEDEDED) }
  var windowBackgroundTint: Color { primary.mix(with: .black, by: isDark ? 0.8 : 0).opacity(0.3) }
  var detailBackground: Color { primary.mix(with: isDark ? .black : .white, by: 0.85) }
  var agentPanelBackground: Color { primary.mix(with: isDark ? .black : .white, by: isDark ? 0.82 : 0.85) }
  var detailStroke: Color { isDark ? Color.white.opacity(0.08) : Color.black.opacity(0.06) }
  var destructive: Color { Color(red: 1, green: 0.4118, blue: 0.4118) }
  var unselectedFill: Color { (isDark ? Color.white : .black).opacity(0.06) }
  var hoverFill: Color { Color.white.opacity(isDark ? 0.16 : 0.55) }
  var pressedFill: Color { Color.white.opacity(isDark ? 0.31 : 0.7) }
  var selectedFill: Color { isDark ? Color(white: 0.04) : .white }
  var selectedStrokeBright: Color { Color.white.opacity(isDark ? 0.35 : 0.98) }
  var selectedStrokeDim: Color { Color.white.opacity(isDark ? 0.08 : 0.98) }
  var selectedShadow: Color { isDark ? Color.white.opacity(0.15) : Color.black.opacity(0.12) }
  var primaryText: Color { isDark ? Color.white.opacity(0.94) : Color.black.opacity(0.86) }
  var secondaryText: Color { isDark ? Color.white.opacity(0.58) : Color.black.opacity(0.48) }
  var selectedText: Color { isDark ? Color.white : .black }
  var attention: Color { Color(nsColor: .systemOrange) }
  var success: Color { Color(nsColor: .systemGreen) }
  var shadow: Color { .black.opacity(isDark ? 0.28 : 0.08) }
  var scrim: Color { Color.black.opacity(0.4) }
  var overlayShadow: Color { Color.black.opacity(0.25) }
  var divider: Color { Color.white.opacity(0.3) }
  var amber: Color { Color(red: 0.89, green: 0.64, blue: 0.28) }
  var mint: Color { Color(red: 0.3, green: 0.72, blue: 0.58) }
  var sky: Color { Color(red: 0.31, green: 0.59, blue: 0.94) }
  var coral: Color { Color(red: 0.9, green: 0.43, blue: 0.38) }
  var violet: Color { Color(red: 0.57, green: 0.45, blue: 0.86) }
  var slate: Color { Color(red: 0.38, green: 0.44, blue: 0.56) }
  var accent: Color { sky }
  var selectedSecondaryText: Color { selectedText.opacity(0.72) }
  var selectedPillFill: Color { selectedText.opacity(0.12) }
  var selectedPillStroke: Color { selectedText.opacity(0.14) }
  var destructiveHoverFill: Color { destructive.opacity(0.85) }

  var selectedStroke: LinearGradient {
    LinearGradient(
      stops: [
        Gradient.Stop(color: selectedStrokeBright, location: 0),
        Gradient.Stop(color: selectedStrokeDim, location: 0.5),
        Gradient.Stop(color: selectedStrokeBright, location: 1),
      ],
      startPoint: .topLeading,
      endPoint: .bottomTrailing
    )
  }

  init(colorScheme: ColorScheme) {
    self.colorScheme = colorScheme
  }
}

extension Color {
  fileprivate init(rgb hex: UInt32) {
    self.init(
      .sRGB,
      red: Double((hex >> 16) & 0xFF) / 255,
      green: Double((hex >> 8) & 0xFF) / 255,
      blue: Double(hex & 0xFF) / 255
    )
  }
}
