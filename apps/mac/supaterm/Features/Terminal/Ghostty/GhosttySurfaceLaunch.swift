import Darwin
import GhosttyKit
import SupatermCLIShared

final class GhosttySurfaceLaunch {
  private let shellCString: UnsafeMutablePointer<CChar>?
  private var inputCString: UnsafeMutablePointer<CChar>?
  private let cleanupToken: SupatermTerminalStartupCleanup?
  let preparationFailed: Bool

  init(
    shellPath: String,
    cliPath: String?,
    startup: SupatermTerminalStartup?
  ) {
    shellCString = SupatermShellCommand.escapedToken(shellPath).withCString { strdup($0) }
    let prepared: SupatermPreparedTerminalStartup?
    if let startup {
      do {
        prepared = try startup.prepare(cliPath: cliPath, shellPath: shellPath)
      } catch {
        SupatermLog.error(
          SupatermLog.terminal,
          "terminal.startup.prepare.failed",
          fields: ["error=\(String(describing: error))"]
        )
        prepared = nil
      }
    } else {
      prepared = nil
    }
    cleanupToken = prepared?.cleanupToken
    inputCString = prepared?.initialInput.withCString { strdup($0) }
    let startupFailed = startup != nil && (prepared == nil || inputCString == nil)
    preparationFailed = shellCString == nil || startupFailed
    if preparationFailed {
      cleanupToken?.cleanup()
    }
  }

  isolated deinit {
    cleanupToken?.cleanup()
    if let shellCString {
      free(shellCString)
    }
    if let inputCString {
      free(inputCString)
    }
  }

  func apply(to config: inout ghostty_surface_config_s) {
    config.command = shellCString.map { UnsafePointer($0) }
    config.initial_input = inputCString.map { UnsafePointer($0) }
  }

  func finishSurfaceCreation(created: Bool) {
    releaseInput()
    if !created {
      cleanupToken?.cleanup()
    }
  }

  func cancel() {
    cleanupToken?.cleanup()
  }

  private func releaseInput() {
    guard let inputCString else { return }
    free(inputCString)
    self.inputCString = nil
  }
}
