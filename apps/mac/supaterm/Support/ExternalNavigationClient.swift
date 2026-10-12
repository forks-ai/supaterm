import AppKit
import ComposableArchitecture
import Foundation

public enum SupatermExternalURL {
  public static var releaseNotes: URL {
    URL(string: "https://github.com/supabitapp/supaterm-legacy/releases/tag/v\(AppBuild.version)")!
  }

  public static var submitGitHubIssue: URL {
    URL(string: "https://github.com/supabitapp/supaterm-legacy/issues/new")!
  }

  public static var changelog: URL {
    URL(string: "https://legacy.supaterm.com/changelog")!
  }
}

public struct ExternalNavigationClient: Sendable {
  public var open: @MainActor @Sendable (URL) -> Bool

  public init(
    open: @escaping @MainActor @Sendable (URL) -> Bool
  ) {
    self.open = open
  }
}

extension ExternalNavigationClient: DependencyKey {
  public static let liveValue = Self(
    open: { url in
      NSWorkspace.shared.open(url)
    }
  )

  public static let testValue = Self(
    open: unimplemented("ExternalNavigationClient.open", placeholder: false)
  )
}

extension DependencyValues {
  public var externalNavigationClient: ExternalNavigationClient {
    get { self[ExternalNavigationClient.self] }
    set { self[ExternalNavigationClient.self] = newValue }
  }
}
