import Darwin
import GhosttyKit
import SupatermCLIShared

final class GhosttySurfaceLaunch {
  private let commandCString: UnsafeMutablePointer<CChar>?
  private var inputCString: UnsafeMutablePointer<CChar>?
  private let cleanupToken: SupatermTerminalStartupCleanup?
  let preparationFailed: Bool

  init(
    shellPath: String,
    cliPath: String?,
    startup: SupatermTerminalStartup?
  ) {
    commandCString = SupatermShellCommand.escapedToken(shellPath).withCString { strdup($0) }
    let prepared: SupatermPreparedTerminalStartup?
    let preparationError: Bool
    do {
      prepared = try startup?.prepare(cliPath: cliPath, shellPath: shellPath)
      preparationError = false
    } catch {
      prepared = nil
      preparationError = true
    }
    cleanupToken = prepared?.cleanupToken
    inputCString = prepared?.initialInput.withCString { strdup($0) }
    preparationFailed =
      preparationError || commandCString == nil || (prepared != nil && inputCString == nil)
    if preparationFailed {
      cleanupToken?.cleanup()
    }
  }

  isolated deinit {
    cleanupToken?.cleanup()
    if let commandCString {
      free(commandCString)
    }
    if let inputCString {
      free(inputCString)
    }
  }

  func apply(to config: inout ghostty_surface_config_s) {
    config.command = commandCString.map { UnsafePointer($0) }
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
