import AppKit
import Carbon.HIToolbox
import SwiftUI
import Synchronization
import Testing

@testable import supaterm

@Suite(.serialized)
@MainActor
struct ConfigDiagnosticsWindowControllerTests {
  init() {
    _ = NSApplication.shared
  }

  @Test
  func nonemptyDiagnosticsPresentWindow() throws {
    let controller = ConfigurationDiagnosticsWindowController()
    let window = try #require(controller.window)
    defer { controller.close() }

    controller.update(messages: ["unknown key"])

    #expect(window.isVisible)
  }

  @Test
  func windowMatchesConfigurationErrorsContract() throws {
    let controller = ConfigurationDiagnosticsWindowController()
    let window = try #require(controller.window)
    defer { controller.close() }

    #expect(window.title == "Configuration Errors")
    #expect(window.styleMask.contains(.titled))
    #expect(window.styleMask.contains(.closable))
    #expect(window.styleMask.contains(.miniaturizable))
    #expect(window.styleMask.contains(.resizable))
    #expect(window.level == .popUpMenu)
    #expect(window.canBecomeKey)
    #expect(window.tabbingMode == .disallowed)
    #expect(!window.isReleasedWhenClosed)
    #expect(!window.isRestorable)
  }

  @Test
  func emptyDiagnosticsCloseWindow() throws {
    let controller = ConfigurationDiagnosticsWindowController()
    let window = try #require(controller.window)
    defer { controller.close() }
    controller.update(messages: ["unknown key"])
    try #require(window.isVisible)

    controller.update(messages: [])

    #expect(!window.isVisible)

    controller.update(messages: ["new error"])

    #expect(controller.window === window)
    #expect(window.isVisible)
  }

  @Test
  func nonemptyUpdatesReuseWindowAndReplaceMessages() throws {
    let controller = ConfigurationDiagnosticsWindowController()
    let window = try #require(controller.window)
    defer { controller.close() }

    controller.update(messages: ["first error"])
    let hostingController = try #require(
      window.contentViewController as? NSHostingController<ConfigurationDiagnosticsView>
    )
    #expect(hostingController.rootView.messages == ["first error"])

    controller.update(messages: ["second error"])

    #expect(controller.window === window)
    #expect(hostingController.rootView.messages == ["second error"])
  }

  @Test
  func ignoreClearsMessagesAndClosesWindow() throws {
    let controller = ConfigurationDiagnosticsWindowController()
    let window = try #require(controller.window)
    defer { controller.close() }
    controller.update(messages: ["unknown key"])
    let hostingController = try #require(
      window.contentViewController as? NSHostingController<ConfigurationDiagnosticsView>
    )

    hostingController.rootView.onIgnore()

    #expect(hostingController.rootView.messages.isEmpty)
    #expect(!window.isVisible)
  }

  @Test
  func escapePerformsCancelAction() throws {
    let controller = ConfigurationDiagnosticsWindowController()
    let window = try #require(controller.window)
    defer { controller.close() }
    controller.update(messages: ["unknown key"])

    let handled = window.performKeyEquivalent(
      with: try keyEvent("\u{1b}", keyCode: UInt16(kVK_Escape))
    )

    #expect(handled)
    #expect(!window.isVisible)
  }

  @Test
  func unrelatedKeyFallsThrough() throws {
    let controller = ConfigurationDiagnosticsWindowController()
    let window = try #require(controller.window)
    defer { controller.close() }
    controller.update(messages: ["unknown key"])

    let handled = window.performKeyEquivalent(
      with: try keyEvent("x", keyCode: UInt16(kVK_ANSI_X))
    )

    #expect(!handled)
    #expect(window.isVisible)
  }

  @Test
  func reloadPostsRuntimeReloadRequestOnce() throws {
    let notificationCenter = NotificationCenter()
    let controller = ConfigurationDiagnosticsWindowController(
      notificationCenter: notificationCenter
    )
    let window = try #require(controller.window)
    defer { controller.close() }
    let reloadCount = Mutex(0)
    let observer = notificationCenter.addObserver(
      forName: .ghosttyRuntimeReloadRequested,
      object: nil,
      queue: nil
    ) { _ in
      reloadCount.withLock { $0 += 1 }
    }
    defer { notificationCenter.removeObserver(observer) }
    controller.update(messages: ["unknown key"])
    let hostingController = try #require(
      window.contentViewController as? NSHostingController<ConfigurationDiagnosticsView>
    )

    hostingController.rootView.onReload()

    #expect(reloadCount.withLock { $0 } == 1)
  }

  @Test
  func returnPerformsDefaultAction() throws {
    let notificationCenter = NotificationCenter()
    let controller = ConfigurationDiagnosticsWindowController(
      notificationCenter: notificationCenter
    )
    let window = try #require(controller.window)
    defer { controller.close() }
    let reloadCount = Mutex(0)
    let observer = notificationCenter.addObserver(
      forName: .ghosttyRuntimeReloadRequested,
      object: nil,
      queue: nil
    ) { _ in
      reloadCount.withLock { $0 += 1 }
    }
    defer { notificationCenter.removeObserver(observer) }
    controller.update(messages: ["unknown key"])

    let handled = window.performKeyEquivalent(
      with: try keyEvent("\r", keyCode: UInt16(kVK_Return))
    )

    #expect(handled)
    #expect(reloadCount.withLock { $0 } == 1)
  }

  private func keyEvent(_ characters: String, keyCode: UInt16) throws -> NSEvent {
    try #require(
      NSEvent.keyEvent(
        with: .keyDown,
        location: .zero,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: 0,
        context: nil,
        characters: characters,
        charactersIgnoringModifiers: characters,
        isARepeat: false,
        keyCode: keyCode
      )
    )
  }
}
