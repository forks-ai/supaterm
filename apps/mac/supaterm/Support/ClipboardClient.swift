import AppKit
import ComposableArchitecture

public struct ClipboardClient: Sendable {
  public var copyString: @MainActor @Sendable (String) -> Bool

  public init(copyString: @escaping @MainActor @Sendable (String) -> Bool) {
    self.copyString = copyString
  }
}

extension ClipboardClient: DependencyKey {
  public static let liveValue = Self(
    copyString: { value in
      let pasteboard = NSPasteboard.general
      pasteboard.clearContents()
      return pasteboard.setString(value, forType: .string)
    }
  )

  public static let testValue = Self(
    copyString: { _ in false }
  )
}

extension DependencyValues {
  public var clipboardClient: ClipboardClient {
    get { self[ClipboardClient.self] }
    set { self[ClipboardClient.self] = newValue }
  }
}
