#if SUPATERM_DEMO
  import Foundation
  import SupatermCLIShared

  extension TerminalHostState {
    @discardableResult
    func demoInjectRunningAgent(
      kind: SupatermAgentKind,
      surfaceID: UUID,
      detail: String,
      sessionID: String?
    ) -> Bool {
      setAgentPresenceActivity(
        AgentActivity(kind: kind, phase: .running, detail: detail),
        for: surfaceID,
        sessionID: sessionID,
        processID: nil
      )
    }

    @discardableResult
    func demoInjectNeedsInputAgent(
      kind: SupatermAgentKind,
      surfaceID: UUID,
      detail: String,
      sessionID: String?
    ) -> Bool {
      setAgentPresenceActivity(
        AgentActivity(kind: kind, phase: .needsInput, detail: detail),
        for: surfaceID,
        sessionID: sessionID,
        processID: nil
      )
    }

    @discardableResult
    func demoInjectPanelMetadata(surfaceID: UUID) -> Bool {
      guard tabID(containing: surfaceID) != nil else { return false }
      storePaneAgentMetadata(.demoRichPanel, for: surfaceID)
      return true
    }

    @discardableResult
    func demoInjectNotification(surfaceID: UUID) -> Bool {
      guard tabID(containing: surfaceID) != nil else { return false }
      paneNotifications[surfaceID, default: []].append(
        PaneNotification(
          attentionState: .unread,
          body: "Deploy preview is ready for approval.",
          createdAt: Date(),
          subtitle: "supaterm/deploy",
          title: "Approval needed",
          origin: .structuredAgent(.attention)
        )
      )
      return true
    }
  }

  extension TerminalHostState.PaneAgentMetadata {
    fileprivate static var demoRichPanel: Self {
      let now = Date()
      return Self(
        progressRows: [
          PaneAgentProgressRow(
            id: "scan-workspace",
            title: "Scan workspace",
            status: .completed
          ),
          PaneAgentProgressRow(
            id: "refresh-preview",
            title: "Refresh preview",
            status: .running
          ),
          PaneAgentProgressRow(
            id: "record-launch-flow",
            title: "Record launch flow",
            status: .pending
          ),
        ],
        branchDetails: PaneAgentBranchDetails(
          branchName: "feat/demo-mode",
          addedLineCount: 120,
          removedLineCount: 18,
          pullRequestStatus: PaneAgentPullRequestStatus(
            kind: .open,
            title: "PR #42 Demo workspace",
            url: URL(string: "https://supaterm.com"),
            addedLineCount: 120,
            removedLineCount: 18,
            checks: PaneAgentPullRequestChecks(
              status: .passing,
              totalCount: 3,
              items: [
                PaneAgentPullRequestCheck(
                  name: "Build",
                  state: .success,
                  workflowName: "macOS",
                  startedAt: now.addingTimeInterval(-540),
                  completedAt: now.addingTimeInterval(-420)
                ),
                PaneAgentPullRequestCheck(
                  name: "Tests",
                  state: .success,
                  workflowName: "macOS",
                  startedAt: now.addingTimeInterval(-420),
                  completedAt: now.addingTimeInterval(-180)
                ),
                PaneAgentPullRequestCheck(
                  name: "Preview",
                  state: .success,
                  workflowName: "Deploy",
                  startedAt: now.addingTimeInterval(-180),
                  completedAt: now.addingTimeInterval(-60)
                ),
              ]
            )
          )
        ),
        artifacts: [
          PaneAgentArtifact(
            title: "localhost:3000",
            url: URL(string: "http://localhost:3000")!
          )
        ],
        sources: [
          .webSearch
        ]
      )
    }
  }
#endif
