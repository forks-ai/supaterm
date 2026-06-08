#if SUPATERM_DEMO
  import Foundation
  import Sharing
  import SupatermCLIShared
  import SupatermSupport

  @MainActor
  enum DemoSeed {
    static func seedCatalogs() {
      @Shared(.terminalSpaceCatalog) var spaceCatalog = TerminalSpaceCatalog.default
      @Shared(.terminalSessionCatalog) var sessionCatalog = TerminalSessionCatalog.default
      @Shared(.terminalPinnedTabCatalog) var pinnedTabCatalog = TerminalPinnedTabCatalog.default
      @Shared(.supatermSettings) var settings = SupatermSettings.default

      $spaceCatalog.withLock {
        $0 = TerminalSpaceCatalog(
          defaultSelectedSpaceID: IDs.space,
          spaces: [
            PersistedTerminalSpace(id: IDs.space, name: "Supaterm")
          ]
        )
      }
      $sessionCatalog.withLock {
        $0 = TerminalSessionCatalog(
          windows: [
            TerminalWindowSession(
              selectedSpaceID: IDs.space,
              spaces: [
                TerminalWindowSpaceSession(
                  id: IDs.space,
                  selectedTabIndex: nil,
                  selectedPinnedTabID: IDs.webTab,
                  tabs: [
                    deploySession,
                    scratchSession,
                  ]
                )
              ]
            )
          ]
        )
      }
      $pinnedTabCatalog.withLock {
        $0 = TerminalPinnedTabCatalog(
          spaces: [
            PersistedPinnedTerminalTabsForSpace(
              id: IDs.space,
              tabs: [
                PersistedPinnedTerminalTab(id: IDs.webTab, session: webSession),
                PersistedPinnedTerminalTab(id: IDs.apiTab, session: apiSession),
              ]
            )
          ]
        )
      }
      $settings.withLock {
        $0.restoreTerminalLayoutEnabled = true
        $0.codingAgentsShowPanel = true
      }
    }

    static func decorate(_ terminals: [TerminalHostState]) {
      for terminal in terminals {
        terminal.demoInjectRunningAgent(
          kind: .codex,
          surfaceID: IDs.webAgentSurface,
          detail: "Running launch prep",
          sessionID: "supaterm-demo-session"
        )
        terminal.demoInjectPanelMetadata(surfaceID: IDs.webAgentSurface)
        terminal.demoInjectRunningAgent(
          kind: .codex,
          surfaceID: IDs.apiSurface,
          detail: "Refreshing API routes",
          sessionID: nil
        )
        terminal.demoInjectNeedsInputAgent(
          kind: .codex,
          surfaceID: IDs.deploySurface,
          detail: "Waiting for approval",
          sessionID: nil
        )
        terminal.demoInjectNotification(surfaceID: IDs.deploySurface)
      }
    }

    static func preservesFakeAgentState(_ surfaceID: UUID) -> Bool {
      fakeAgentSurfaceIDs.contains(surfaceID)
    }

    private static let fakeAgentSurfaceIDs: Set<UUID> = [
      IDs.webAgentSurface,
      IDs.apiSurface,
      IDs.deploySurface,
    ]

    private static let webSession = TerminalTabSession(
      isPinned: true,
      lockedTitle: "supaterm/web",
      focusedPaneIndex: 0,
      root: .split(
        TerminalPaneSplitSession(
          direction: .horizontal,
          ratio: 0.58,
          left: .leaf(
            TerminalPaneLeafSession(
              id: IDs.webAgentSurface,
              workingDirectoryPath: workingDirectoryPath("code/supaterm/web"),
              titleOverride: "supaterm/web"
            )
          ),
          right: .leaf(
            TerminalPaneLeafSession(
              id: IDs.webShellSurface,
              workingDirectoryPath: workingDirectoryPath("code/supaterm/web"),
              titleOverride: "shell"
            )
          )
        )
      )
    )

    private static let apiSession = TerminalTabSession(
      isPinned: true,
      lockedTitle: "supaterm/api",
      focusedPaneIndex: 0,
      root: .leaf(
        TerminalPaneLeafSession(
          id: IDs.apiSurface,
          workingDirectoryPath: workingDirectoryPath("code/supaterm/api"),
          titleOverride: "supaterm/api"
        )
      )
    )

    private static let deploySession = TerminalTabSession(
      isPinned: false,
      lockedTitle: "supaterm/deploy",
      focusedPaneIndex: 0,
      root: .leaf(
        TerminalPaneLeafSession(
          id: IDs.deploySurface,
          workingDirectoryPath: workingDirectoryPath("code/supaterm/deploy"),
          titleOverride: "supaterm/deploy"
        )
      )
    )

    private static let scratchSession = TerminalTabSession(
      isPinned: false,
      lockedTitle: "scratch",
      focusedPaneIndex: 0,
      root: .leaf(
        TerminalPaneLeafSession(
          id: IDs.scratchSurface,
          workingDirectoryPath: workingDirectoryPath("code/supaterm/scratch"),
          titleOverride: "scratch"
        )
      )
    )

    private static func workingDirectoryPath(_ relativePath: String) -> String {
      let home = FileManager.default.homeDirectoryForCurrentUser.path
      let path = NSString(string: home).appendingPathComponent(relativePath)
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory),
        isDirectory.boolValue
      else {
        return home
      }
      return path
    }

    private enum IDs {
      static let space = TerminalSpaceID(rawValue: UUID(uuidString: "4F9DA8C0-7B80-42C4-A828-B7A7E4E1D3A1")!)
      static let webTab = TerminalTabID(rawValue: UUID(uuidString: "F4218391-DB8F-43DD-830C-B63D6F877D81")!)
      static let apiTab = TerminalTabID(rawValue: UUID(uuidString: "85F58292-F7C3-47DB-89D7-B96DCC6A2771")!)
      static let webAgentSurface = UUID(uuidString: "8F02B7F2-4F60-465B-90DF-14C03BF6D482")!
      static let webShellSurface = UUID(uuidString: "F6D8226D-0C92-40D4-B5E8-52B3E850D675")!
      static let apiSurface = UUID(uuidString: "C095C9A1-7E44-4BD2-A9F5-7F322221B495")!
      static let deploySurface = UUID(uuidString: "E6BD77C4-835A-4F9B-9953-8B5A44A124B5")!
      static let scratchSurface = UUID(uuidString: "0AF060BC-0F4B-4D18-86DF-C74F268040C8")!
    }
  }
#endif
