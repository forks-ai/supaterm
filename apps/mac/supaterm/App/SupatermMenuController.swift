import AppKit
import SupatermSettingsFeature
import SupatermSupport
import SwiftUI

@MainActor
final class SupatermMenuController: NSObject {
  private struct MenuShortcutKey: Equatable {
    let keyEquivalent: String
    let modifierMask: NSEvent.ModifierFlags

    init(shortcut: KeyboardShortcut) {
      self.keyEquivalent = shortcut.key.character.description.lowercased()
      self.modifierMask = NSEvent.ModifierFlags(swiftUIFlags: shortcut.modifiers)
        .intersection(.deviceIndependentFlagsMask)
    }

    func matches(_ event: NSEvent) -> Bool {
      let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
      guard eventModifiers == modifierMask else { return false }
      let eventKeys = Set([event.charactersIgnoringModifiers, event.characters].compactMap { $0?.lowercased() })
      return eventKeys.contains(keyEquivalent)
    }
  }

  private struct GhosttyBindingMenuItem {
    let shortcut: MenuShortcutKey
    let item: NSMenuItem
  }

  private enum MenuItemIdentifier {
    static let about = NSUserInterfaceItemIdentifier("app.supabit.supaterm.app.about")
    static let checkForUpdates = NSUserInterfaceItemIdentifier("app.supabit.supaterm.app.checkForUpdates")
    static let quit = NSUserInterfaceItemIdentifier("app.supabit.supaterm.app.quit")
    static let quitTerminatingSessions = NSUserInterfaceItemIdentifier(
      "app.supabit.supaterm.app.quitTerminatingSessions")
    static let settings = NSUserInterfaceItemIdentifier("app.supabit.supaterm.app.settings")
    static let newWindow = NSUserInterfaceItemIdentifier("app.supabit.supaterm.file.newWindow")
    static let newTab = NSUserInterfaceItemIdentifier("app.supabit.supaterm.file.newTab")
    static let splitRight = NSUserInterfaceItemIdentifier("app.supabit.supaterm.file.splitRight")
    static let splitLeft = NSUserInterfaceItemIdentifier("app.supabit.supaterm.file.splitLeft")
    static let splitDown = NSUserInterfaceItemIdentifier("app.supabit.supaterm.file.splitDown")
    static let splitUp = NSUserInterfaceItemIdentifier("app.supabit.supaterm.file.splitUp")
    static let closeSurface = NSUserInterfaceItemIdentifier("app.supabit.supaterm.file.close")
    static let closeTab = NSUserInterfaceItemIdentifier("app.supabit.supaterm.file.closeTab")
    static let closeWindow = NSUserInterfaceItemIdentifier("app.supabit.supaterm.file.closeWindow")
    static let closeAllWindows = NSUserInterfaceItemIdentifier("app.supabit.supaterm.file.closeAllWindows")
    static let terminateAllTerminalSessions = NSUserInterfaceItemIdentifier(
      "app.supabit.supaterm.file.terminateAllTerminalSessions")
    static let openCommandPalette = NSUserInterfaceItemIdentifier("app.supabit.supaterm.file.openCommandPalette")
    static let copy = NSUserInterfaceItemIdentifier("app.supabit.supaterm.edit.copy")
    static let paste = NSUserInterfaceItemIdentifier("app.supabit.supaterm.edit.paste")
    static let pasteSelection = NSUserInterfaceItemIdentifier("app.supabit.supaterm.edit.pasteSelection")
    static let selectAll = NSUserInterfaceItemIdentifier("app.supabit.supaterm.edit.selectAll")
    static let find = NSUserInterfaceItemIdentifier("app.supabit.supaterm.edit.find")
    static let findNext = NSUserInterfaceItemIdentifier("app.supabit.supaterm.edit.findNext")
    static let findPrevious = NSUserInterfaceItemIdentifier("app.supabit.supaterm.edit.findPrevious")
    static let hideFindBar = NSUserInterfaceItemIdentifier("app.supabit.supaterm.edit.hideFindBar")
    static let selectionForFind = NSUserInterfaceItemIdentifier("app.supabit.supaterm.edit.selectionForFind")
    static let toggleSidebar = NSUserInterfaceItemIdentifier("app.supabit.supaterm.view.toggleSidebar")
    static let toggleAgentPanel = NSUserInterfaceItemIdentifier("app.supabit.supaterm.view.toggleAgentPanel")
    static let forkAgentSession = NSUserInterfaceItemIdentifier("app.supabit.supaterm.view.forkAgentSession")
    static let copyAgentSessionID = NSUserInterfaceItemIdentifier("app.supabit.supaterm.view.copyAgentSessionID")
    static let changeTabTitle = NSUserInterfaceItemIdentifier("app.supabit.supaterm.view.changeTabTitle")
    static let changeTerminalTitle = NSUserInterfaceItemIdentifier("app.supabit.supaterm.view.changeTerminalTitle")
    static let nextTab = NSUserInterfaceItemIdentifier("app.supabit.supaterm.tabs.next")
    static let previousTab = NSUserInterfaceItemIdentifier("app.supabit.supaterm.tabs.previous")
    static let selectLastTab = NSUserInterfaceItemIdentifier("app.supabit.supaterm.tabs.last")
    static let selectTabPrefix = "app.supabit.supaterm.tabs.select."
    static let selectSpacePrefix = "app.supabit.supaterm.spaces.select."
    static let zoomSplit = NSUserInterfaceItemIdentifier("app.supabit.supaterm.window.zoomSplit")
    static let previousSplit = NSUserInterfaceItemIdentifier("app.supabit.supaterm.window.previousSplit")
    static let nextSplit = NSUserInterfaceItemIdentifier("app.supabit.supaterm.window.nextSplit")
    static let selectSplitAbove = NSUserInterfaceItemIdentifier("app.supabit.supaterm.window.selectSplitAbove")
    static let selectSplitBelow = NSUserInterfaceItemIdentifier("app.supabit.supaterm.window.selectSplitBelow")
    static let selectSplitLeft = NSUserInterfaceItemIdentifier("app.supabit.supaterm.window.selectSplitLeft")
    static let selectSplitRight = NSUserInterfaceItemIdentifier("app.supabit.supaterm.window.selectSplitRight")
    static let equalizeSplits = NSUserInterfaceItemIdentifier("app.supabit.supaterm.window.equalizeSplits")
    static let moveSplitDividerUp = NSUserInterfaceItemIdentifier("app.supabit.supaterm.window.moveSplitDividerUp")
    static let moveSplitDividerDown = NSUserInterfaceItemIdentifier("app.supabit.supaterm.window.moveSplitDividerDown")
    static let moveSplitDividerLeft = NSUserInterfaceItemIdentifier("app.supabit.supaterm.window.moveSplitDividerLeft")
    static let moveSplitDividerRight = NSUserInterfaceItemIdentifier(
      "app.supabit.supaterm.window.moveSplitDividerRight")
    static let submitGitHubIssue = NSUserInterfaceItemIdentifier("app.supabit.supaterm.help.submitGitHubIssue")
    static let changelog = NSUserInterfaceItemIdentifier("app.supabit.supaterm.help.changelog")
  }

  private let registry: TerminalWindowRegistry
  private var observers: [NSObjectProtocol] = []
  private var requestNewWindow: @MainActor () -> Bool = { false }
  private var requestShowSettings: @MainActor (SettingsFeature.Tab) -> Bool = { _ in false }
  private var requestSubmitGitHubIssue: @MainActor () -> Bool = {
    ExternalNavigationClient.liveValue.open(SupatermExternalURL.submitGitHubIssue)
  }
  private var agentSessionShortcutItems: [GhosttyBindingMenuItem] = []
  private var ghosttyBindingItems: [GhosttyBindingMenuItem] = []

  private var appName: String {
    if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
      !name.isEmpty
    {
      return name
    }
    if let name = Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String,
      !name.isEmpty
    {
      return name
    }
    return ProcessInfo.processInfo.processName
  }

  private lazy var servicesMenu = NSMenu(title: "Services")

  private lazy var mainMenu: NSMenu = {
    let menu = NSMenu(title: "Supaterm")
    menu.addItem(topLevelMenuItem(title: appName, submenu: appMenu))
    menu.addItem(topLevelMenuItem(title: "File", submenu: fileMenu))
    menu.addItem(topLevelMenuItem(title: "Edit", submenu: editMenu))
    menu.addItem(topLevelMenuItem(title: "View", submenu: viewMenu))
    menu.addItem(topLevelMenuItem(title: "Tabs", submenu: tabsMenu))
    menu.addItem(topLevelMenuItem(title: "Spaces", submenu: spacesMenu))
    menu.addItem(topLevelMenuItem(title: "Window", submenu: windowMenu))
    menu.addItem(topLevelMenuItem(title: "Help", submenu: helpMenu))
    return menu
  }()

  private lazy var appMenu: NSMenu = {
    let menu = NSMenu(title: appName)
    menu.addItem(menuItem(MenuItemIdentifier.about))
    menu.addItem(menuItem(MenuItemIdentifier.settings))
    menu.addItem(.separator())
    menu.addItem(menuItem(MenuItemIdentifier.checkForUpdates))
    menu.addItem(.separator())
    let servicesItem = NSMenuItem(title: "Services", action: nil, keyEquivalent: "")
    servicesItem.submenu = servicesMenu
    menu.addItem(servicesItem)
    menu.addItem(.separator())
    menu.addItem(systemItem(title: "Hide \(appName)", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
    let hideOthers = systemItem(
      title: "Hide Others",
      action: #selector(NSApplication.hideOtherApplications(_:)),
      keyEquivalent: "h"
    )
    hideOthers.keyEquivalentModifierMask = [.command, .option]
    menu.addItem(hideOthers)
    menu.addItem(systemItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:))))
    menu.addItem(.separator())
    menu.addItem(menuItem(MenuItemIdentifier.quitTerminatingSessions))
    menu.addItem(menuItem(MenuItemIdentifier.quit))
    return menu
  }()

  private lazy var fileMenu: NSMenu = {
    let menu = NSMenu(title: "File")
    menu.addItem(menuItem(MenuItemIdentifier.newWindow))
    menu.addItem(menuItem(MenuItemIdentifier.newTab))
    menu.addItem(menuItem(MenuItemIdentifier.openCommandPalette))
    menu.addItem(.separator())
    menu.addItem(menuItem(MenuItemIdentifier.splitRight))
    menu.addItem(menuItem(MenuItemIdentifier.splitLeft))
    menu.addItem(menuItem(MenuItemIdentifier.splitDown))
    menu.addItem(menuItem(MenuItemIdentifier.splitUp))
    menu.addItem(.separator())
    menu.addItem(menuItem(MenuItemIdentifier.closeSurface))
    menu.addItem(menuItem(MenuItemIdentifier.closeTab))
    menu.addItem(menuItem(MenuItemIdentifier.closeWindow))
    menu.addItem(menuItem(MenuItemIdentifier.closeAllWindows))
    menu.addItem(.separator())
    menu.addItem(menuItem(MenuItemIdentifier.terminateAllTerminalSessions))
    return menu
  }()

  private lazy var editMenu: NSMenu = {
    let menu = NSMenu(title: "Edit")
    menu.addItem(systemItem(title: "Undo", action: #selector(UndoManager.undo)))
    menu.addItem(systemItem(title: "Redo", action: #selector(UndoManager.redo)))
    menu.addItem(.separator())
    menu.addItem(menuItem(MenuItemIdentifier.copy))
    menu.addItem(menuItem(MenuItemIdentifier.paste))
    menu.addItem(menuItem(MenuItemIdentifier.pasteSelection))
    menu.addItem(menuItem(MenuItemIdentifier.selectAll))
    menu.addItem(.separator())
    let findMenuItem = NSMenuItem(title: "Find", action: nil, keyEquivalent: "")
    findMenuItem.submenu = findMenu
    menu.addItem(findMenuItem)
    return menu
  }()

  private lazy var findMenu: NSMenu = {
    let menu = NSMenu(title: "Find")
    menu.addItem(menuItem(MenuItemIdentifier.find))
    menu.addItem(menuItem(MenuItemIdentifier.findNext))
    menu.addItem(menuItem(MenuItemIdentifier.findPrevious))
    menu.addItem(.separator())
    menu.addItem(menuItem(MenuItemIdentifier.hideFindBar))
    menu.addItem(.separator())
    menu.addItem(menuItem(MenuItemIdentifier.selectionForFind))
    return menu
  }()

  private lazy var viewMenu: NSMenu = {
    let menu = NSMenu(title: "View")
    menu.addItem(menuItem(MenuItemIdentifier.toggleSidebar))
    menu.addItem(menuItem(MenuItemIdentifier.toggleAgentPanel))
    menu.addItem(menuItem(MenuItemIdentifier.forkAgentSession))
    menu.addItem(menuItem(MenuItemIdentifier.copyAgentSessionID))
    menu.addItem(.separator())
    menu.addItem(menuItem(MenuItemIdentifier.changeTabTitle))
    menu.addItem(menuItem(MenuItemIdentifier.changeTerminalTitle))
    return menu
  }()

  private lazy var tabsMenu: NSMenu = {
    let menu = NSMenu(title: "Tabs")
    menu.addItem(menuItem(MenuItemIdentifier.nextTab))
    menu.addItem(menuItem(MenuItemIdentifier.previousTab))
    menu.addItem(.separator())
    for item in slotItems(withPrefix: MenuItemIdentifier.selectTabPrefix) {
      menu.addItem(item)
    }
    menu.addItem(menuItem(MenuItemIdentifier.selectLastTab))
    return menu
  }()

  private lazy var spacesMenu: NSMenu = {
    let menu = NSMenu(title: "Spaces")
    for item in slotItems(withPrefix: MenuItemIdentifier.selectSpacePrefix) {
      menu.addItem(item)
    }
    return menu
  }()

  private lazy var windowMenu: NSMenu = {
    let menu = NSMenu(title: "Window")
    menu.addItem(systemItem(title: "Minimize", action: #selector(NSWindow.performMiniaturize(_:)), keyEquivalent: "m"))
    menu.addItem(systemItem(title: "Zoom", action: #selector(NSWindow.performZoom(_:))))
    menu.addItem(.separator())
    menu.addItem(menuItem(MenuItemIdentifier.zoomSplit))
    menu.addItem(menuItem(MenuItemIdentifier.previousSplit))
    menu.addItem(menuItem(MenuItemIdentifier.nextSplit))
    let selectSplitMenuItem = NSMenuItem(title: "Select Split", action: nil, keyEquivalent: "")
    selectSplitMenuItem.submenu = selectSplitMenu
    menu.addItem(selectSplitMenuItem)
    let resizeSplitMenuItem = NSMenuItem(title: "Resize Split", action: nil, keyEquivalent: "")
    resizeSplitMenuItem.submenu = resizeSplitMenu
    menu.addItem(resizeSplitMenuItem)
    menu.addItem(.separator())
    menu.addItem(systemItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:))))
    return menu
  }()

  private lazy var helpMenu: NSMenu = {
    let menu = NSMenu(title: "Help")
    menu.addItem(menuItem(MenuItemIdentifier.changelog))
    menu.addItem(menuItem(MenuItemIdentifier.submitGitHubIssue))
    return menu
  }()

  private lazy var selectSplitMenu: NSMenu = {
    let menu = NSMenu(title: "Select Split")
    menu.addItem(menuItem(MenuItemIdentifier.selectSplitAbove))
    menu.addItem(menuItem(MenuItemIdentifier.selectSplitBelow))
    menu.addItem(menuItem(MenuItemIdentifier.selectSplitLeft))
    menu.addItem(menuItem(MenuItemIdentifier.selectSplitRight))
    return menu
  }()

  private lazy var resizeSplitMenu: NSMenu = {
    let menu = NSMenu(title: "Resize Split")
    menu.addItem(menuItem(MenuItemIdentifier.equalizeSplits))
    menu.addItem(.separator())
    menu.addItem(menuItem(MenuItemIdentifier.moveSplitDividerUp))
    menu.addItem(menuItem(MenuItemIdentifier.moveSplitDividerDown))
    menu.addItem(menuItem(MenuItemIdentifier.moveSplitDividerLeft))
    menu.addItem(menuItem(MenuItemIdentifier.moveSplitDividerRight))
    return menu
  }()

  private struct MenuEntry {
    let spec: SupatermMenuItemSpec
    let item: NSMenuItem
  }

  private lazy var menuEntries: [MenuEntry] = menuItemSpecs().map { spec in
    MenuEntry(spec: spec, item: makeItem(from: spec))
  }

  private func menuItem(_ id: NSUserInterfaceItemIdentifier) -> NSMenuItem {
    guard let entry = menuEntries.first(where: { $0.spec.id == id }) else {
      preconditionFailure("Missing menu item spec for \(id.rawValue)")
    }
    return entry.item
  }

  private func slotItems(withPrefix prefix: String) -> [NSMenuItem] {
    menuEntries
      .filter { $0.spec.id?.rawValue.hasPrefix(prefix) == true }
      .map(\.item)
  }

  func menuItemSpecs() -> [SupatermMenuItemSpec] {
    appMenuSpecs() + fileMenuSpecs() + editMenuSpecs() + viewMenuSpecs()
      + tabsMenuSpecs() + spacesMenuSpecs() + windowMenuSpecs() + helpMenuSpecs()
  }

  private func appMenuSpecs() -> [SupatermMenuItemSpec] {
    [
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.about,
        title: "About \(appName)",
        action: #selector(about(_:))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.settings,
        title: "Settings...",
        action: #selector(showSettings(_:)),
        shortcut: .ghosttyAction(
          "open_config",
          defaultShortcut: KeyboardShortcut(",", modifiers: .command)
        )
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.checkForUpdates,
        title: "Check for Updates...",
        action: #selector(checkForUpdates(_:)),
        shortcut: .ghosttyAction(
          "check_for_updates",
          defaultShortcut: KeyboardShortcut("u", modifiers: [.command, .shift])
        )
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.quitTerminatingSessions,
        title: "Quit \(appName) and Close All Sessions",
        action: #selector(quitTerminatingSessions(_:))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.quit,
        title: "Quit \(appName)",
        action: #selector(quit(_:)),
        shortcut: .ghosttyAction(
          "quit",
          defaultShortcut: KeyboardShortcut("q", modifiers: .command)
        )
      ),
    ]
  }

  private func fileMenuSpecs() -> [SupatermMenuItemSpec] {
    [
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.newWindow,
        title: "New Window",
        action: #selector(newWindow(_:)),
        symbol: "macwindow.badge.plus",
        shortcut: .command(.newWindow)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.newTab,
        title: "New Tab",
        action: #selector(newTab(_:)),
        symbol: "macwindow",
        shortcut: .command(.newTab)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.openCommandPalette,
        title: "Open Command Palette",
        action: #selector(openCommandPalette(_:)),
        symbol: "magnifyingglass",
        shortcut: .ghosttyAction(
          "toggle_command_palette",
          defaultShortcut: KeyboardShortcut("p", modifiers: [.command, .shift])
        )
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.splitRight,
        title: "Split Right",
        action: #selector(splitRight(_:)),
        symbol: "rectangle.righthalf.inset.filled",
        shortcut: .command(.newSplit(.right))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.splitLeft,
        title: "Split Left",
        action: #selector(splitLeft(_:)),
        symbol: "rectangle.leadinghalf.inset.filled",
        shortcut: .command(.newSplit(.left))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.splitDown,
        title: "Split Down",
        action: #selector(splitDown(_:)),
        symbol: "rectangle.bottomhalf.inset.filled",
        shortcut: .command(.newSplit(.down))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.splitUp,
        title: "Split Up",
        action: #selector(splitUp(_:)),
        symbol: "rectangle.tophalf.inset.filled",
        shortcut: .command(.newSplit(.up))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.closeSurface,
        title: "Close Pane",
        action: #selector(closeSurface(_:)),
        symbol: "xmark",
        shortcut: .command(.closeSurface)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.closeTab,
        title: "Close Tab",
        action: #selector(closeTab(_:)),
        shortcut: .command(.closeTab)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.closeWindow,
        title: "Close Window",
        action: #selector(closeWindow(_:)),
        shortcut: .command(.closeWindow)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.closeAllWindows,
        title: "Close All Windows",
        action: #selector(closeAllWindows(_:)),
        shortcut: .command(.closeAllWindows)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.terminateAllTerminalSessions,
        title: "Terminate All Terminal Sessions...",
        action: #selector(terminateAllTerminalSessions(_:))
      ),
    ]
  }

  private func editMenuSpecs() -> [SupatermMenuItemSpec] {
    [
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.copy,
        title: "Copy",
        action: #selector(GhosttySurfaceView.copy(_:)),
        shortcut: .command(.copyToClipboard),
        targetsController: false
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.paste,
        title: "Paste",
        action: #selector(GhosttySurfaceView.paste(_:)),
        shortcut: .command(.pasteFromClipboard),
        targetsController: false
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.pasteSelection,
        title: "Paste Selection",
        action: #selector(GhosttySurfaceView.pasteSelection(_:)),
        shortcut: .command(.pasteFromSelection),
        targetsController: false
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.selectAll,
        title: "Select All",
        action: #selector(GhosttySurfaceView.selectAll(_:)),
        shortcut: .command(.selectAll),
        targetsController: false
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.find,
        title: "Find...",
        action: #selector(find(_:)),
        shortcut: .command(.startSearch)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.findNext,
        title: "Find Next",
        action: #selector(findNext(_:)),
        shortcut: .command(.navigateSearch(.next))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.findPrevious,
        title: "Find Previous",
        action: #selector(findPrevious(_:)),
        shortcut: .command(.navigateSearch(.previous))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.hideFindBar,
        title: "Hide Find Bar",
        action: #selector(findHide(_:)),
        shortcut: .command(.endSearch)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.selectionForFind,
        title: "Use Selection for Find",
        action: #selector(selectionForFind(_:)),
        shortcut: .command(.searchSelection)
      ),
    ]
  }

  private func viewMenuSpecs() -> [SupatermMenuItemSpec] {
    [
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.toggleSidebar,
        title: "Toggle Sidebar",
        action: #selector(toggleSidebar(_:)),
        shortcut: .fixed(KeyboardShortcut("s", modifiers: .command))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.toggleAgentPanel,
        title: "Toggle Agent Panel",
        action: #selector(toggleAgentPanel(_:)),
        shortcut: .fixed(AgentPanelShortcut.toggleVisibility)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.forkAgentSession,
        title: "Fork Agent Session",
        action: #selector(forkAgentSession(_:)),
        shortcut: .fixedRouted(AgentPanelShortcut.forkSession)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.copyAgentSessionID,
        title: "Copy Agent Session ID",
        action: #selector(copyAgentSessionID(_:)),
        shortcut: .fixedRouted(AgentPanelShortcut.copySessionID)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.changeTabTitle,
        title: "Change Tab Title...",
        action: #selector(changeTabTitle(_:)),
        symbol: "pencil.line",
        shortcut: .command(.promptTabTitle)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.changeTerminalTitle,
        title: "Change Terminal Title...",
        action: #selector(changeTerminalTitle(_:)),
        symbol: "pencil.line",
        shortcut: .command(.promptSurfaceTitle)
      ),
    ]
  }

  private func tabsMenuSpecs() -> [SupatermMenuItemSpec] {
    var specs: [SupatermMenuItemSpec] = [
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.nextTab,
        title: "Next Tab",
        action: #selector(nextTab(_:)),
        shortcut: .command(.nextTab)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.previousTab,
        title: "Previous Tab",
        action: #selector(previousTab(_:)),
        shortcut: .command(.previousTab)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.selectLastTab,
        title: "Last Tab",
        action: #selector(selectLastTab(_:)),
        shortcut: .command(.lastTab)
      ),
    ]
    let lastTab = specs.removeLast()
    specs.append(
      contentsOf: (1...10).map { slot in
        SupatermMenuItemSpec(
          id: NSUserInterfaceItemIdentifier(MenuItemIdentifier.selectTabPrefix + "\(slot)"),
          title: "Tab \(slot)",
          action: #selector(selectTab(_:)),
          shortcut: .command(.goToTab(slot)),
          slot: slot
        )
      }
    )
    specs.append(lastTab)
    return specs
  }

  private func spacesMenuSpecs() -> [SupatermMenuItemSpec] {
    (1...10).map { slot in
      SupatermMenuItemSpec(
        id: NSUserInterfaceItemIdentifier(MenuItemIdentifier.selectSpacePrefix + "\(slot)"),
        title: "Space \(slot)",
        action: #selector(selectSpace(_:)),
        shortcut: .fixed(
          KeyboardShortcut(
            KeyEquivalent(Character(slot == 10 ? "0" : "\(slot)")),
            modifiers: .control
          )
        ),
        slot: slot
      )
    }
  }

  private func windowMenuSpecs() -> [SupatermMenuItemSpec] {
    [
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.zoomSplit,
        title: "Zoom Split",
        action: #selector(zoomSplit(_:)),
        symbol: "arrow.up.left.and.arrow.down.right",
        shortcut: .command(.toggleSplitZoom)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.previousSplit,
        title: "Select Previous Split",
        action: #selector(previousSplit(_:)),
        symbol: "chevron.backward.2",
        shortcut: .command(.goToSplit(.previous))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.nextSplit,
        title: "Select Next Split",
        action: #selector(nextSplit(_:)),
        symbol: "chevron.forward.2",
        shortcut: .command(.goToSplit(.next))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.selectSplitAbove,
        title: "Select Split Above",
        action: #selector(selectSplitAbove(_:)),
        symbol: "arrow.up",
        shortcut: .command(.goToSplit(.up))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.selectSplitBelow,
        title: "Select Split Below",
        action: #selector(selectSplitBelow(_:)),
        symbol: "arrow.down",
        shortcut: .command(.goToSplit(.down))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.selectSplitLeft,
        title: "Select Split Left",
        action: #selector(selectSplitLeft(_:)),
        symbol: "arrow.left",
        shortcut: .command(.goToSplit(.left))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.selectSplitRight,
        title: "Select Split Right",
        action: #selector(selectSplitRight(_:)),
        symbol: "arrow.right",
        shortcut: .command(.goToSplit(.right))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.equalizeSplits,
        title: "Equalize Panes",
        action: #selector(equalizeSplits(_:)),
        symbol: "inset.filled.topleft.topright.bottomleft.bottomright.rectangle",
        shortcut: .command(.equalizeSplits)
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.moveSplitDividerUp,
        title: "Move Divider Up",
        action: #selector(moveSplitDividerUp(_:)),
        symbol: "arrow.up.to.line",
        shortcut: .command(.resizeSplit(.up, 10))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.moveSplitDividerDown,
        title: "Move Divider Down",
        action: #selector(moveSplitDividerDown(_:)),
        symbol: "arrow.down.to.line",
        shortcut: .command(.resizeSplit(.down, 10))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.moveSplitDividerLeft,
        title: "Move Divider Left",
        action: #selector(moveSplitDividerLeft(_:)),
        symbol: "arrow.left.to.line",
        shortcut: .command(.resizeSplit(.left, 10))
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.moveSplitDividerRight,
        title: "Move Divider Right",
        action: #selector(moveSplitDividerRight(_:)),
        symbol: "arrow.right.to.line",
        shortcut: .command(.resizeSplit(.right, 10))
      ),
    ]
  }

  private func helpMenuSpecs() -> [SupatermMenuItemSpec] {
    [
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.changelog,
        title: "Changelog",
        action: #selector(openChangelog(_:)),
        symbol: "list.bullet.rectangle"
      ),
      SupatermMenuItemSpec(
        id: MenuItemIdentifier.submitGitHubIssue,
        title: "Submit GitHub Issue",
        action: #selector(submitGitHubIssue(_:)),
        symbol: "exclamationmark.bubble"
      ),
    ]
  }

  init(registry: TerminalWindowRegistry) {
    self.registry = registry
  }

  func setNewWindowAction(_ action: @escaping @MainActor () -> Bool) {
    requestNewWindow = action
  }

  func setShowSettingsAction(_ action: @escaping @MainActor (SettingsFeature.Tab) -> Bool) {
    requestShowSettings = action
  }

  func setSubmitGitHubIssueAction(_ action: @escaping @MainActor () -> Bool) {
    requestSubmitGitHubIssue = action
  }

  func install() {
    installObservers()
    NSApp.mainMenu = mainMenu
    NSApp.servicesMenu = servicesMenu
    NSApp.windowsMenu = windowMenu
    NSApp.helpMenu = helpMenu
    refresh()
  }

  func refresh() {
    if NSApp.mainMenu !== mainMenu {
      NSApp.mainMenu = mainMenu
      NSApp.servicesMenu = servicesMenu
      NSApp.windowsMenu = windowMenu
      NSApp.helpMenu = helpMenu
    }

    ghosttyBindingItems = []
    agentSessionShortcutItems = []
    for entry in menuEntries {
      switch entry.spec.shortcut {
      case .command(let command):
        syncShortcut(command: command, item: entry.item)
      case .ghosttyAction(let action, let defaultShortcut):
        syncShortcut(action: action, item: entry.item, defaultShortcut: defaultShortcut)
      case .fixed(let shortcut):
        SupatermMenuShortcut.apply(shortcut, to: entry.item)
      case .fixedRouted(let shortcut):
        SupatermMenuShortcut.apply(shortcut, to: entry.item)
        agentSessionShortcutItems.append(
          GhosttyBindingMenuItem(shortcut: MenuShortcutKey(shortcut: shortcut), item: entry.item)
        )
      case .none:
        break
      }
    }
    mainMenu.update()
  }

  @discardableResult
  func performGhosttyBindingMenuKeyEquivalent(with event: NSEvent) -> Bool {
    let item =
      (agentSessionShortcutItems + ghosttyBindingItems)
      .lazy
      .first { $0.shortcut.matches(event) }?.item
    guard let item else { return false }
    if item.identifier == MenuItemIdentifier.settings,
      registry.keyboardShortcut(forAction: "open_config") != nil
    {
      return performShowSettings(.terminal)
    }
    item.menu?.update()
    guard item.isEnabled else { return false }
    guard let action = item.action else { return false }
    return NSApp.sendAction(action, to: item.target, from: item)
  }

  @discardableResult
  func performNewWindow() -> Bool {
    requestNewWindow()
  }

  @discardableResult
  func performShowSettings(_ tab: SettingsFeature.Tab) -> Bool {
    requestShowSettings(tab)
  }

  @discardableResult
  func performUpdateMenuAction() -> Bool {
    registry.requestUpdateMenuActionInKeyWindow()
  }

  @discardableResult
  func performCheckForUpdates() -> Bool {
    performUpdateMenuAction()
  }

  @discardableResult
  func performOpenChangelog() -> Bool {
    ExternalNavigationClient.liveValue.open(SupatermExternalURL.changelog)
  }

  @discardableResult
  func performSubmitGitHubIssue() -> Bool {
    requestSubmitGitHubIssue()
  }

  @discardableResult
  func performCloseAllWindows() -> Bool {
    registry.requestCloseAllWindows()
  }

  @discardableResult
  func performQuit() -> Bool {
    if let performer = NSApp.delegate as? any GhosttyAppActionPerforming {
      return performer.performQuit()
    }
    NSApp.terminate(nil)
    return true
  }

  @discardableResult
  func performQuitTerminatingSessions() -> Bool {
    if let performer = NSApp.delegate as? any GhosttyAppActionPerforming {
      return performer.performQuitTerminatingSessions()
    }
    registry.terminateAllTerminalSessions()
    NSApp.terminate(nil)
    return true
  }

  @objc func about(_ sender: Any?) {
    _ = performShowSettings(.about)
  }

  @objc func checkForUpdates(_ sender: Any?) {
    _ = performUpdateMenuAction()
  }

  @objc func quit(_ sender: Any?) {
    _ = performQuit()
  }

  @objc func quitTerminatingSessions(_ sender: Any?) {
    _ = performQuitTerminatingSessions()
  }

  @objc func showSettings(_ sender: Any?) {
    _ = performShowSettings(.general)
  }

  @objc func newWindow(_ sender: Any?) {
    _ = performNewWindow()
  }

  @objc func newTab(_ sender: Any?) {
    registry.requestNewTabInKeyWindow()
  }

  @objc func splitRight(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.newSplit(.right))
  }

  @objc func splitLeft(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.newSplit(.left))
  }

  @objc func splitDown(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.newSplit(.down))
  }

  @objc func splitUp(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.newSplit(.up))
  }

  @objc func closeSurface(_ sender: Any?) {
    _ = performCloseSurface(for: NSApp.keyWindow, sender: sender)
  }

  @objc func closeTab(_ sender: Any?) {
    registry.requestCloseTabInKeyWindow()
  }

  @objc func closeWindow(_ sender: Any?) {
    guard let window = NSApp.keyWindow ?? NSApp.windows.first(where: \.isVisible) else { return }
    window.performClose(sender)
  }

  @objc func closeAllWindows(_ sender: Any?) {
    _ = registry.requestCloseAllWindows()
  }

  @objc func terminateAllTerminalSessions(_ sender: Any?) {
    registry.terminateAllTerminalSessions()
  }

  @objc func openCommandPalette(_ sender: Any?) {
    registry.requestToggleCommandPaletteInKeyWindow()
  }

  @objc func openChangelog(_ sender: Any?) {
    _ = performOpenChangelog()
  }

  @objc func submitGitHubIssue(_ sender: Any?) {
    _ = performSubmitGitHubIssue()
  }

  @objc func find(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.startSearch)
  }

  @objc func findNext(_ sender: Any?) {
    registry.requestNavigateSearchInKeyWindow(.next)
  }

  @objc func findPrevious(_ sender: Any?) {
    registry.requestNavigateSearchInKeyWindow(.previous)
  }

  @objc func findHide(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.endSearch)
  }

  @objc func selectionForFind(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.searchSelection)
  }

  @objc func toggleSidebar(_ sender: Any?) {
    registry.requestToggleSidebarInKeyWindow()
  }

  @objc func toggleAgentPanel(_ sender: Any?) {
    registry.requestToggleAgentPanelInKeyWindow()
  }

  @objc func forkAgentSession(_ sender: Any?) {
    registry.requestForkAgentPanelSessionInKeyWindow(direction: .right)
  }

  @objc func copyAgentSessionID(_ sender: Any?) {
    registry.requestCopyAgentPanelSessionIDInKeyWindow()
  }

  @objc func changeTabTitle(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.promptTabTitle)
  }

  @objc func changeTerminalTitle(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.promptSurfaceTitle)
  }

  @objc func zoomSplit(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.toggleSplitZoom)
  }

  @objc func previousSplit(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.goToSplit(.previous))
  }

  @objc func nextSplit(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.goToSplit(.next))
  }

  @objc func selectSplitAbove(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.goToSplit(.up))
  }

  @objc func selectSplitBelow(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.goToSplit(.down))
  }

  @objc func selectSplitLeft(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.goToSplit(.left))
  }

  @objc func selectSplitRight(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.goToSplit(.right))
  }

  @objc func equalizeSplits(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.equalizeSplits)
  }

  @objc func moveSplitDividerUp(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.resizeSplit(.up, 10))
  }

  @objc func moveSplitDividerDown(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.resizeSplit(.down, 10))
  }

  @objc func moveSplitDividerLeft(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.resizeSplit(.left, 10))
  }

  @objc func moveSplitDividerRight(_ sender: Any?) {
    registry.requestBindingActionInKeyWindow(.resizeSplit(.right, 10))
  }

  @objc func nextTab(_ sender: Any?) {
    registry.requestNextTabInKeyWindow()
  }

  @objc func previousTab(_ sender: Any?) {
    registry.requestPreviousTabInKeyWindow()
  }

  @objc func selectTab(_ sender: Any?) {
    guard let slot = (sender as? NSMenuItem)?.representedObject as? NSNumber else { return }
    registry.requestSelectTabInKeyWindow(slot.intValue)
  }

  @objc func selectLastTab(_ sender: Any?) {
    registry.requestSelectLastTabInKeyWindow()
  }

  @objc func selectSpace(_ sender: Any?) {
    guard let slot = (sender as? NSMenuItem)?.representedObject as? NSNumber else { return }
    registry.requestSelectSpaceInKeyWindow(slot.intValue)
  }

  private func syncShortcut(command: SupatermCommand, item: NSMenuItem?) {
    syncShortcut(
      action: command.ghosttyBindingAction,
      item: item,
      defaultShortcut: command.defaultKeyboardShortcut
    )
  }

  private func syncShortcut(
    action: String,
    item: NSMenuItem?,
    defaultShortcut: KeyboardShortcut? = nil
  ) {
    guard let item else { return }
    if let shortcut = registry.keyboardShortcut(forAction: action) {
      SupatermMenuShortcut.apply(shortcut, to: item)
      syncGhosttyBindingItem(item, shortcut: shortcut)
      return
    }
    if registry.hasShortcutSource {
      SupatermMenuShortcut.apply(nil, to: item)
      return
    }
    SupatermMenuShortcut.apply(defaultShortcut, to: item)
    syncGhosttyBindingItem(item, shortcut: defaultShortcut)
  }

  private func syncGhosttyBindingItem(_ item: NSMenuItem, shortcut: KeyboardShortcut?) {
    guard let shortcut else { return }
    ghosttyBindingItems.append(
      GhosttyBindingMenuItem(
        shortcut: MenuShortcutKey(shortcut: shortcut),
        item: item
      )
    )
  }

  private func installObservers() {
    guard observers.isEmpty else { return }
    let center = NotificationCenter.default
    observers.append(
      center.addObserver(
        forName: NSWindow.didBecomeKeyNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.refresh()
        }
      }
    )
    observers.append(
      center.addObserver(
        forName: NSWindow.didResignKeyNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.refresh()
        }
      }
    )
    observers.append(
      center.addObserver(
        forName: .ghosttyRuntimeConfigDidChange,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        Task { @MainActor [weak self] in
          self?.refresh()
        }
      }
    )
  }

  private func topLevelMenuItem(title: String, submenu: NSMenu) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
    item.submenu = submenu
    return item
  }

  private func makeItem(from spec: SupatermMenuItemSpec) -> NSMenuItem {
    let item = NSMenuItem(title: spec.title, action: spec.action, keyEquivalent: "")
    item.identifier = spec.id
    if spec.targetsController {
      item.target = self
    }
    if let symbol = spec.symbol {
      item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: spec.title)
    }
    if let slot = spec.slot {
      item.representedObject = slot as NSNumber
    }
    if case .none = spec.shortcut {
      SupatermMenuShortcut.apply(nil, to: item)
    }
    return item
  }

  private func systemItem(
    title: String,
    action: Selector,
    keyEquivalent: String = ""
  ) -> NSMenuItem {
    let item = NSMenuItem(title: title, action: action, keyEquivalent: keyEquivalent)
    if !keyEquivalent.isEmpty {
      item.keyEquivalentModifierMask = .command
    }
    return item
  }

  @discardableResult
  func performCloseSurface(for keyWindow: NSWindow?, sender: Any?) -> Bool {
    if registry.closesWindowDirectly(keyWindow) {
      SupatermLog.notice(
        SupatermLog.terminal,
        "terminal.close.menuRequest",
        fields: ["target=nonTerminalWindow"]
      )
      keyWindow?.performClose(sender)
      return true
    }
    SupatermLog.notice(
      SupatermLog.terminal,
      "terminal.close.menuRequest",
      fields: ["target=terminalSurface"]
    )
    registry.requestCloseSurfaceInKeyWindow()
    return true
  }
}

extension SupatermMenuController: NSMenuItemValidation {
  func validateMenuItem(_ item: NSMenuItem) -> Bool {
    let context = registry.menuContext()

    switch item.identifier {
    case MenuItemIdentifier.checkForUpdates:
      item.title = context.updateMenuItemText
      return context.isUpdateMenuItemEnabled
    case MenuItemIdentifier.newTab:
      return context.availability.hasWindow
    case MenuItemIdentifier.openCommandPalette:
      return context.availability.hasWindow
    case MenuItemIdentifier.splitRight,
      MenuItemIdentifier.splitLeft,
      MenuItemIdentifier.splitDown,
      MenuItemIdentifier.splitUp:
      return context.availability.hasSurface
    case MenuItemIdentifier.closeSurface:
      return context.availability.hasSurface || context.closesKeyWindowDirectly
    case MenuItemIdentifier.closeTab:
      return context.availability.hasTab
    case MenuItemIdentifier.closeWindow,
      MenuItemIdentifier.closeAllWindows,
      MenuItemIdentifier.toggleSidebar:
      return context.availability.hasWindow
    case MenuItemIdentifier.toggleAgentPanel:
      return context.availability.hasAgentPanel
    case MenuItemIdentifier.forkAgentSession,
      MenuItemIdentifier.copyAgentSessionID:
      return context.availability.hasAgentPanelSession
    case MenuItemIdentifier.terminateAllTerminalSessions:
      return context.availability.hasAnySurface
    case MenuItemIdentifier.find,
      MenuItemIdentifier.findNext,
      MenuItemIdentifier.findPrevious,
      MenuItemIdentifier.changeTerminalTitle,
      MenuItemIdentifier.selectionForFind,
      MenuItemIdentifier.zoomSplit,
      MenuItemIdentifier.previousSplit,
      MenuItemIdentifier.nextSplit,
      MenuItemIdentifier.selectSplitAbove,
      MenuItemIdentifier.selectSplitBelow,
      MenuItemIdentifier.selectSplitLeft,
      MenuItemIdentifier.selectSplitRight,
      MenuItemIdentifier.equalizeSplits,
      MenuItemIdentifier.moveSplitDividerUp,
      MenuItemIdentifier.moveSplitDividerDown,
      MenuItemIdentifier.moveSplitDividerLeft,
      MenuItemIdentifier.moveSplitDividerRight:
      return context.availability.hasSurface
    case MenuItemIdentifier.hideFindBar:
      return context.hasSearch
    case MenuItemIdentifier.nextTab,
      MenuItemIdentifier.previousTab,
      MenuItemIdentifier.changeTabTitle,
      MenuItemIdentifier.selectLastTab:
      return context.visibleTabCount > 0
    default:
      return validateIndexedMenuItem(item, context: context)
    }
  }

  private func validateIndexedMenuItem(
    _ item: NSMenuItem,
    context: TerminalWindowRegistry.MenuContext
  ) -> Bool {
    guard let identifier = item.identifier?.rawValue else { return true }
    if let slot = Int(identifier.replacingOccurrences(of: MenuItemIdentifier.selectTabPrefix, with: "")),
      identifier.hasPrefix(MenuItemIdentifier.selectTabPrefix)
    {
      return context.visibleTabCount >= slot
    }
    if let slot = Int(identifier.replacingOccurrences(of: MenuItemIdentifier.selectSpacePrefix, with: "")),
      identifier.hasPrefix(MenuItemIdentifier.selectSpacePrefix)
    {
      return context.spaceCount >= slot
    }
    return true
  }
}

enum SupatermMenuShortcut {
  static func apply(_ shortcut: KeyboardShortcut?, to item: NSMenuItem) {
    guard let shortcut else {
      item.keyEquivalent = ""
      item.keyEquivalentModifierMask = []
      return
    }

    item.keyEquivalent = shortcut.key.character.description
    item.keyEquivalentModifierMask = NSEvent.ModifierFlags(swiftUIFlags: shortcut.modifiers)
  }
}

extension NSEvent.ModifierFlags {
  fileprivate init(swiftUIFlags: EventModifiers) {
    var result: NSEvent.ModifierFlags = []
    if swiftUIFlags.contains(.shift) { result.insert(.shift) }
    if swiftUIFlags.contains(.control) { result.insert(.control) }
    if swiftUIFlags.contains(.option) { result.insert(.option) }
    if swiftUIFlags.contains(.command) { result.insert(.command) }
    if swiftUIFlags.contains(.capsLock) { result.insert(.capsLock) }
    self = result
  }
}
