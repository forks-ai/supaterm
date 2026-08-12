import Darwin
import Foundation
import GhosttyKit
import SupatermCLIShared

final class GhosttySurfaceLaunch {
  private let command: String?
  private let initialInput: String?
  private let arguments: [String]
  private let startupFileURL: URL?
  private var deferredInput: String?
  let preparationFailed: Bool

  init(
    shellPath: String,
    startup: SupatermTerminalStartup?,
    defersInputUntilShellReady: Bool = false,
    temporaryDirectory: URL = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
  ) {
    let input: String?
    let startupFile: GhosttyShellStartupFile?
    let preparationFailed: Bool
    switch startup {
    case .exec(let arguments, _):
      command = nil
      input = nil
      self.arguments = arguments
      startupFile = nil
      preparationFailed = false
    case .shell(let script):
      command = SupatermShellCommand.escapedToken(shellPath)
      arguments = []
      if !SupatermTerminalStartup.shell(script).isValid {
        input = nil
        startupFile = nil
        preparationFailed = true
      } else if defersInputUntilShellReady {
        input = script.hasSuffix("\n") ? script : script + "\n"
        startupFile = nil
        preparationFailed = false
      } else {
        do {
          let file = try GhosttyShellStartupFile(
            script: script,
            shellPath: shellPath,
            temporaryDirectory: temporaryDirectory
          )
          input = file.initialInput
          startupFile = file
          preparationFailed = false
        } catch {
          SupatermLog.error(
            SupatermLog.terminal,
            "terminal.startup.prepare.failed",
            fields: ["error=\(String(reflecting: type(of: error)))"]
          )
          input = nil
          startupFile = nil
          preparationFailed = true
        }
      }
    case nil:
      command = SupatermShellCommand.escapedToken(shellPath)
      input = nil
      arguments = []
      startupFile = nil
      preparationFailed = false
    }
    startupFileURL = startupFile?.fileURL
    self.preparationFailed = preparationFailed

    if defersInputUntilShellReady {
      deferredInput = input
      initialInput = nil
    } else {
      deferredInput = nil
      initialInput = input
    }
  }

  deinit {
    if let startupFileURL {
      unlink(startupFileURL.path)
    }
  }

  func withConfiguration<Result>(
    _ config: inout ghostty_surface_config_s,
    _ body: (inout ghostty_surface_config_s) -> Result
  ) -> Result {
    Self.withCString(command) { command in
      config.command = command
      return Self.withCString(initialInput) { initialInput in
        config.initial_input = initialInput
        return Self.withCStringArray(arguments) { arguments, count in
          config.command_argv = arguments
          config.command_argv_count = count
          return body(&config)
        }
      }
    }
  }

  func takeDeferredInput() -> String? {
    defer { deferredInput = nil }
    return deferredInput
  }

  private static func withCString<Result>(
    _ value: String?,
    _ body: (UnsafePointer<CChar>?) -> Result
  ) -> Result {
    guard let value else { return body(nil) }
    return value.withCString(body)
  }

  static func withCStringArray<Result>(
    _ values: [String],
    _ body: (UnsafePointer<UnsafePointer<CChar>?>?, Int) -> Result
  ) -> Result {
    guard !values.isEmpty else {
      return body(nil, 0)
    }

    let pointers: [UnsafePointer<CChar>?] = values.map { value in
      UnsafePointer(value.withCString { strdup($0)! })
    }
    defer {
      for pointer in pointers {
        free(UnsafeMutablePointer(mutating: pointer))
      }
    }
    return pointers.withUnsafeBufferPointer { buffer in
      body(buffer.baseAddress, buffer.count)
    }
  }
}

private struct GhosttyShellStartupFile {
  let initialInput: String
  let fileURL: URL

  init(script: String, shellPath: String, temporaryDirectory: URL) throws {
    let shellName = URL(fileURLWithPath: shellPath).lastPathComponent.lowercased()
    let suffix = shellName == "nu" || shellName == "nushell" ? ".nu" : ""
    var pathTemplate = Array(
      temporaryDirectory.appendingPathComponent(
        "supaterm-shell-startup.XXXXXX\(suffix)"
      ).path.utf8CString
    )
    let descriptor: Int32 = pathTemplate.withUnsafeMutableBufferPointer { buffer in
      guard let baseAddress = buffer.baseAddress else { return -1 }
      return mkstemps(baseAddress, Int32(suffix.utf8.count))
    }
    guard descriptor >= 0 else { throw Self.currentPOSIXError() }
    defer { close(descriptor) }

    let fileURL = pathTemplate.withUnsafeBufferPointer { buffer in
      URL(fileURLWithPath: String(cString: buffer.baseAddress!))
    }
    self.fileURL = fileURL
    do {
      guard fchmod(descriptor, 0o600) == 0 else { throw Self.currentPOSIXError() }
      let scriptPath = SupatermShellCommand.escapedToken(fileURL.path)
      try Self.write(
        Data(
          """
          /usr/bin/tail -n +3 -- \(scriptPath)
          /bin/rm -f -- \(scriptPath)
          \(script)
          """.utf8
        ),
        to: descriptor
      )
      initialInput = Self.sourceCommand(scriptPath: scriptPath, shellName: shellName) + "\n"
      guard initialInput.utf8.count < 1_024 else { throw POSIXError(.ENAMETOOLONG) }
    } catch {
      unlink(fileURL.path)
      throw error
    }
  }

  private static func sourceCommand(scriptPath: String, shellName: String) -> String {
    switch shellName {
    case "csh", "tcsh", "fish", "nu", "nushell":
      "source \(scriptPath)"
    case "elvish":
      "eval (slurp <\(scriptPath))"
    default:
      ". \(scriptPath)"
    }
  }

  private static func write(_ data: Data, to descriptor: Int32) throws {
    try data.withUnsafeBytes { bytes in
      guard let baseAddress = bytes.baseAddress else { return }
      var written = 0
      while written < bytes.count {
        let result = Darwin.write(
          descriptor,
          baseAddress.advanced(by: written),
          bytes.count - written
        )
        if result > 0 {
          written += result
        } else if result != -1 || errno != EINTR {
          throw currentPOSIXError()
        }
      }
    }
  }

  private static func currentPOSIXError() -> POSIXError {
    POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
  }
}
