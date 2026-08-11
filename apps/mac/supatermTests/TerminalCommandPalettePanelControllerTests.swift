import AppKit
import Testing

@testable import supaterm

@MainActor
struct TerminalCommandPalettePanelTests {
  @Test
  func keyPanelHandlesNumberedPaletteShortcut() throws {
    let panel = TerminalCommandPalettePanel(contentViewController: NSViewController())
    defer { panel.close() }
    var activatedSlot: Int?
    panel.onPaletteShortcut = { activatedSlot = $0 }
    let event = try #require(
      NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: .command,
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: "2",
        charactersIgnoringModifiers: "2",
        isARepeat: false,
        keyCode: 0
      )
    )

    #expect(panel.performKeyEquivalent(with: event))
    #expect(activatedSlot == 2)
  }
}
