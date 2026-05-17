import Foundation

nonisolated struct PaneAgentPanelPresentation: Equatable, Sendable {
  var progressRows: [PaneAgentProgressRow] = []
  var branchDetails: PaneAgentBranchDetails?
  var artifacts: [PaneAgentArtifact] = []
  var sources: [PaneAgentSource] = []

  var isEmpty: Bool {
    progressRows.isEmpty
      && branchDetails == nil
      && artifacts.isEmpty
      && sources.isEmpty
  }
}

nonisolated struct PaneAgentProgressRow: Equatable, Identifiable, Sendable {
  enum Status: Equatable, Sendable {
    case pending
    case running
    case completed
  }

  let id: String
  let title: String
  let status: Status
}

nonisolated struct PaneAgentBranchDetails: Equatable, Sendable {
  let branchName: String
  let addedLineCount: Int
  let removedLineCount: Int
  let hasWorkingTreeChanges: Bool
  let pullRequestStatus: PaneAgentPullRequestStatus
}

nonisolated struct PaneAgentPullRequestStatus: Equatable, Sendable {
  enum Kind: Equatable, Sendable {
    case unavailable
    case none
    case open
    case draft
    case merged
    case closed
  }

  let kind: Kind
  let title: String
  let url: URL?
  let addedLineCount: Int?
  let removedLineCount: Int?
  let checks: PaneAgentPullRequestChecks?

  static let unavailable = Self(
    kind: .unavailable,
    title: "Pull request status unavailable",
    url: nil,
    addedLineCount: nil,
    removedLineCount: nil,
    checks: nil
  )

  static let none = Self(
    kind: .none,
    title: "No pull request",
    url: nil,
    addedLineCount: nil,
    removedLineCount: nil,
    checks: nil
  )

  static func createPullRequest(url: URL?) -> Self {
    Self(
      kind: .none,
      title: "Create pull request",
      url: url,
      addedLineCount: nil,
      removedLineCount: nil,
      checks: nil
    )
  }
}

nonisolated struct PaneAgentPullRequestChecks: Equatable, Sendable {
  enum Status: Equatable, Sendable {
    case pending
    case passing
    case failing

    var isPending: Bool {
      self == .pending
    }

    var isFailing: Bool {
      self == .failing
    }
  }

  let status: Status
  let totalCount: Int
  let items: [PaneAgentPullRequestCheck]

  init(status: Status, totalCount: Int, items: [PaneAgentPullRequestCheck]) {
    self.status = status
    self.totalCount = totalCount
    self.items = items
  }

  var title: String {
    if totalCount == 0 {
      return "Checks (0)"
    }
    if status.isFailing {
      return "Checks failing (\(totalCount))"
    }
    if status.isPending {
      return "Checks pending (\(totalCount))"
    }
    return "Checks passed (\(totalCount))"
  }

  var itemCounts: [PaneAgentPullRequestCheck.Status: Int] {
    items.reduce(into: [:]) { counts, item in
      counts[item.status, default: 0] += 1
    }
  }
}

nonisolated struct PaneAgentPullRequestCheck: Equatable, Identifiable, Sendable {
  enum Status: Equatable, Hashable, Sendable {
    case pending
    case passing
    case failing
    case skipped

    var isPending: Bool {
      self == .pending
    }

    var isFailing: Bool {
      self == .failing
    }
  }

  let id: String
  let name: String
  let status: Status

  init(name: String, status: Status) {
    self.id = name
    self.name = name
    self.status = status
  }
}

nonisolated struct PaneAgentArtifact: Equatable, Identifiable, Sendable {
  let id: String
  let title: String
  let url: URL

  init(title: String, url: URL) {
    self.id = url.absoluteString
    self.title = title
    self.url = url
  }
}

nonisolated struct PaneAgentSource: Equatable, Identifiable, Sendable {
  enum Kind: Equatable, Sendable {
    case webSearch
  }

  let id: String
  let title: String
  let kind: Kind

  static let webSearch = Self(
    id: "web-search",
    title: "Web search",
    kind: .webSearch
  )
}
