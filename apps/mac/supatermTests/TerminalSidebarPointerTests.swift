import AppKit
import ComposableArchitecture
import SupaTheme
import SwiftUI
import Testing

@testable import supaterm

@MainActor
struct TerminalSidebarPointerTests {
  @Test
  func tabRowRoutesPlainAndModifiedClicksThroughCollectionController() async throws {
    let host = TerminalHostState(managesTerminalSurfaces: false)
    let manager = host.spaceManager.tabManager
    let firstTabID = manager.createTab(title: "First")
    let secondTabID = manager.createTab(title: "Second")
    manager.selectTab(secondTabID)
    let firstTab = try #require(host.tabs.first { $0.id == firstTabID })
    let recorder = TerminalCommandRecorder()
    let store = Store(initialState: TerminalWindowFeature.State()) {
      TerminalWindowFeature()
    } withDependencies: {
      $0.terminalClient.send = { recorder.record($0) }
    }
    let outline = TerminalSidebarOutline(
      roots: [
        TerminalSidebarOutline.Root(content: .tab(firstTabID), isPinned: false),
        TerminalSidebarOutline.Root(content: .tab(secondTabID), isPinned: false),
      ],
      collapsedGroupIDs: [],
      topologyRevision: 1,
      spaceID: TerminalSidebarTestFixture.primarySpaceID
    )
    let selectionState = TerminalSidebarTabSelectionState()
    let collectionView = TerminalSidebarCollectionView(
      frame: NSRect(x: 0, y: 0, width: 240, height: 100)
    )
    collectionView.onRowMouseDown = { entryID, event in
      guard entryID == .tab(firstTabID) else { return false }
      if event.modifierFlags.contains(.command) {
        selectionState.toggle(firstTabID, primaryTabID: secondTabID)
      } else {
        selectionState.clear()
        _ = store.send(.tabSelected(firstTabID))
      }
      return true
    }
    collectionView.onRowMouseUp = { entryID, _ in
      entryID == .tab(firstTabID)
    }
    let item = TerminalSidebarCollectionItem()
    item.host(
      TerminalSidebarHostedRow(
        presentation: .tab(presentation(firstTab)),
        context: TerminalSidebarRowContext(
          store: store,
          terminal: host,
          palette: Palette(colorScheme: .dark),
          renameState: TerminalSidebarRenameState(),
          groupHeaderHoverState: TerminalSidebarGroupHoverState(),
          tabSelectionState: selectionState,
          outline: outline,
          fixedHoveredGroupID: nil,
          actions: rowActions
        )
      ),
      entryID: .tab(firstTabID)
    )
    item.view.frame = NSRect(x: 0, y: 0, width: 240, height: 60)
    collectionView.isSelectable = false
    collectionView.addSubview(item.view)
    let window = NSWindow(
      contentRect: collectionView.frame,
      styleMask: [.titled],
      backing: .buffered,
      defer: false
    )
    window.contentView = collectionView
    window.makeKeyAndOrderFront(nil)
    defer {
      window.contentView = nil
      window.orderOut(nil)
    }
    try await Task.sleep(for: .milliseconds(100))
    item.view.layoutSubtreeIfNeeded()
    let hostedView = try #require(item.view.subviews.first)
    let location = hostedView.convert(
      NSPoint(x: hostedView.bounds.midX, y: hostedView.bounds.midY),
      to: nil
    )
    let commandMouseDown = try #require(
      mouseEvent(.leftMouseDown, at: location, in: window, modifiers: .command)
    )
    let commandMouseUp = try #require(
      mouseEvent(.leftMouseUp, at: location, in: window, modifiers: .command)
    )

    NSApp.sendEvent(commandMouseDown)
    NSApp.sendEvent(commandMouseUp)
    for _ in 0..<5 { await Task.yield() }
    #expect(recorder.commands.isEmpty)
    #expect(
      selectionState.orderedTabIDs(primaryTabID: secondTabID, outline: outline)
        == [firstTabID, secondTabID]
    )

    let mouseDown = try #require(mouseEvent(.leftMouseDown, at: location, in: window))
    let mouseUp = try #require(mouseEvent(.leftMouseUp, at: location, in: window))
    NSApp.sendEvent(mouseDown)
    NSApp.sendEvent(mouseUp)
    for _ in 0..<5 { await Task.yield() }
    #expect(recorder.commands == [.selectTab(firstTabID)])
  }

  private func presentation(_ tab: TerminalTabItem) -> TerminalSidebarTabRowPresentation {
    TerminalSidebarTabRowPresentation(
      tab: tab,
      groupID: nil,
      rootIsPinned: false,
      notificationPresentation: nil,
      paneWorkingDirectories: [],
      unreadCount: 0,
      terminalProgress: nil,
      hasTerminalBell: false,
      showsAgentMarks: false,
      showsAgentSpinner: false,
      shortcutHint: nil,
      showsShortcutHint: false
    )
  }

  private var rowActions: TerminalSidebarRowActions {
    TerminalSidebarRowActions(
      toggleGroupCollapsed: { _ in },
      createTabInGroup: { _ in },
      renameGroup: { _, _ in false },
      setGroupColor: { _, _ in },
      toggleGroupPinned: { _ in },
      ungroup: { _ in },
      closeGroup: { _ in },
      newTab: {}
    )
  }

  private func mouseEvent(
    _ type: NSEvent.EventType,
    at location: NSPoint,
    in window: NSWindow,
    modifiers: NSEvent.ModifierFlags = []
  ) -> NSEvent? {
    NSEvent.mouseEvent(
      with: type,
      location: location,
      modifierFlags: modifiers,
      timestamp: ProcessInfo.processInfo.systemUptime,
      windowNumber: window.windowNumber,
      context: nil,
      eventNumber: 1,
      clickCount: 1,
      pressure: type == .leftMouseDown ? 1 : 0
    )
  }

}
