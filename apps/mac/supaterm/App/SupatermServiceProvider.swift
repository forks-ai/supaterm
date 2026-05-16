import AppKit
import Foundation

final class SupatermServiceProvider: NSObject {
  private enum OpenTarget {
    case tab
    case window
  }

  private static let errorNoPaths = NSString(string: "Could not load any file paths from the pasteboard.")

  private let openTabs: ([String]) -> Void
  private let openWindows: ([String]) -> Void

  init(
    openTabs: @escaping ([String]) -> Void,
    openWindows: @escaping ([String]) -> Void
  ) {
    self.openTabs = openTabs
    self.openWindows = openWindows
    super.init()
  }

  @objc func openTab(
    _ pasteboard: NSPasteboard,
    userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString>
  ) {
    openTerminal(from: pasteboard, target: .tab, error: error)
  }

  @objc func openWindow(
    _ pasteboard: NSPasteboard,
    userData: String?,
    error: AutoreleasingUnsafeMutablePointer<NSString>
  ) {
    openTerminal(from: pasteboard, target: .window, error: error)
  }

  static func directoryPaths(from pasteboard: NSPasteboard) -> [String] {
    guard let urls = pasteboard.readObjects(forClasses: [NSURL.self]) as? [URL] else {
      return []
    }
    return directoryPaths(for: urls)
  }

  static func directoryPaths(for urls: [URL]) -> [String] {
    Array(
      Set(
        urls.map { url in
          directoryURL(for: url).standardizedFileURL.path(percentEncoded: false)
        }
      )
    )
    .sorted()
  }

  private func openTerminal(
    from pasteboard: NSPasteboard,
    target: OpenTarget,
    error: AutoreleasingUnsafeMutablePointer<NSString>
  ) {
    let paths = Self.directoryPaths(from: pasteboard)
    guard !paths.isEmpty else {
      error.pointee = Self.errorNoPaths
      return
    }

    switch target {
    case .tab:
      openTabs(paths)
    case .window:
      openWindows(paths)
    }
  }

  private static func directoryURL(for url: URL) -> URL {
    if url.hasDirectoryPath {
      return url
    }
    if (try? url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true {
      return url
    }
    return url.deletingLastPathComponent()
  }
}
