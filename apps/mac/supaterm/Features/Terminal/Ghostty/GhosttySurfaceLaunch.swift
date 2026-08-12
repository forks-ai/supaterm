import Darwin
import GhosttyKit
import SupatermCLIShared

final class GhosttySurfaceLaunch {
  private let command: String?
  private let initialInput: String?
  private let arguments: [String]
  private var deferredInput: String?

  init(
    shellPath: String,
    startup: SupatermTerminalStartup?,
    defersInputUntilShellReady: Bool = false
  ) {
    let input: String?
    switch startup {
    case .exec(let arguments, _):
      command = nil
      input = nil
      self.arguments = arguments
    case .shell(let script):
      command = SupatermShellCommand.escapedToken(shellPath)
      input = script.hasSuffix("\n") ? script : script + "\n"
      arguments = []
    case nil:
      command = SupatermShellCommand.escapedToken(shellPath)
      input = nil
      arguments = []
    }

    if defersInputUntilShellReady {
      deferredInput = input
      initialInput = nil
    } else {
      deferredInput = nil
      initialInput = input
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
