import Darwin
import Foundation

public enum SupatermTerminalStartup: Equatable, Sendable, Codable {
  case arguments([String])
  case script(String)

  public static let maximumArgumentsPayloadSize = 8 * 1_024 * 1_024
  private static let transportDirectoryPrefix = "supaterm-startup-"
  private static let argumentsFileName = "arguments.json"

  private enum CodingKeys: String, CodingKey {
    case kind
    case value
  }

  private enum Kind: String, Codable {
    case arguments
    case script
  }

  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    switch try container.decode(Kind.self, forKey: .kind) {
    case .arguments:
      self = .arguments(try container.decode([String].self, forKey: .value))
    case .script:
      self = .script(try container.decode(String.self, forKey: .value))
    }
  }

  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    switch self {
    case .arguments(let arguments):
      try container.encode(Kind.arguments, forKey: .kind)
      try container.encode(arguments, forKey: .value)
    case .script(let script):
      try container.encode(Kind.script, forKey: .kind)
      try container.encode(script, forKey: .value)
    }
  }

  public func prepare(
    cliPath: String?,
    shellPath: String = SupatermShellCommand.loginShellPath(),
    temporaryDirectory: URL = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
  ) throws -> SupatermPreparedTerminalStartup {
    switch self {
    case .arguments(let arguments):
      return try Self.prepareArguments(
        arguments,
        cliPath: cliPath,
        temporaryDirectory: temporaryDirectory
      )
    case .script(let script):
      return try Self.prepareScript(
        script,
        shellPath: shellPath,
        temporaryDirectory: temporaryDirectory
      )
    }
  }

  public static func consumeArguments(payloadPath: String) throws -> [String] {
    guard
      let payloadURL = validatedPayloadURL(payloadPath),
      let data = readAndRemovePayload(payloadURL)
    else {
      throw SupatermTerminalStartupError.invalidArguments
    }
    defer { _ = rmdir(payloadURL.deletingLastPathComponent().path) }
    guard
      let arguments = try? JSONDecoder().decode([String].self, from: data),
      validArguments(arguments)
    else {
      throw SupatermTerminalStartupError.invalidArguments
    }
    return arguments
  }

  public static func validArguments(_ arguments: [String]) -> Bool {
    guard
      let command = arguments.first,
      !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    else {
      return false
    }
    return arguments.allSatisfy {
      !$0.unicodeScalars.contains(where: { $0.value == 0 })
    }
  }

  private static func prepareArguments(
    _ arguments: [String],
    cliPath: String?,
    temporaryDirectory: URL
  ) throws -> SupatermPreparedTerminalStartup {
    guard validArguments(arguments) else {
      throw SupatermTerminalStartupError.invalidArguments
    }
    guard let cliPath, Self.isExecutableFile(atPath: cliPath) else {
      throw SupatermTerminalStartupError.invalidCLIPath
    }
    let argumentsData = try JSONEncoder().encode(arguments)
    guard argumentsData.count <= maximumArgumentsPayloadSize else {
      throw SupatermTerminalStartupError.invalidArguments
    }
    reapStaleTransports(temporaryDirectory: temporaryDirectory)
    let transport = try makeTransportDirectory(in: temporaryDirectory)
    let directoryURL = transport.directoryURL
    let argumentsURL = directoryURL.appendingPathComponent(argumentsFileName, isDirectory: false)
    let launcherURL = directoryURL.appendingPathComponent("launch", isDirectory: false)
    let initialInput = launcherURL.path + "\n"
    guard Self.isShellSafePath(launcherURL.path), initialInput.utf8.count < 1_024 else {
      transport.cleanupToken.cleanup()
      throw SupatermTerminalStartupError.invalidTemporaryDirectory
    }
    do {
      try Self.write(
        argumentsData,
        to: argumentsURL,
        permissions: 0o600
      )
      let script = Self.launcherScript(
        cliPath: cliPath,
        argumentsPath: argumentsURL.path,
        launcherPath: launcherURL.path
      )
      try Self.write(Data(script.utf8), to: launcherURL, permissions: 0o700)
      return SupatermPreparedTerminalStartup(
        initialInput: initialInput,
        cleanupToken: transport.cleanupToken
      )
    } catch {
      transport.cleanupToken.cleanup()
      throw error
    }
  }

  private static func prepareScript(
    _ script: String,
    shellPath: String,
    temporaryDirectory: URL
  ) throws -> SupatermPreparedTerminalStartup {
    guard
      !script.unicodeScalars.contains(where: { $0.value == 0 }),
      isExecutableFile(atPath: shellPath)
    else {
      throw SupatermTerminalStartupError.invalidArguments
    }
    reapStaleTransports(temporaryDirectory: temporaryDirectory)
    let transport = try makeTransportDirectory(in: temporaryDirectory)
    let directoryURL = transport.directoryURL
    let scriptURL = directoryURL.appendingPathComponent(
      scriptFileName(shellPath: shellPath),
      isDirectory: false
    )
    let initialInput = sourceCommand(scriptPath: scriptURL.path, shellPath: shellPath) + "\n"
    guard isShellSafePath(scriptURL.path), initialInput.utf8.count < 1_024 else {
      transport.cleanupToken.cleanup()
      throw SupatermTerminalStartupError.invalidTemporaryDirectory
    }
    let contents = """
      /bin/rm -f -- \(scriptURL.path)
      /bin/rmdir \(directoryURL.path)
      \(script)
      """
    do {
      try write(Data(contents.utf8), to: scriptURL, permissions: 0o600)
      return SupatermPreparedTerminalStartup(
        initialInput: initialInput,
        cleanupToken: transport.cleanupToken
      )
    } catch {
      transport.cleanupToken.cleanup()
      throw error
    }
  }

  private static func makeTransportDirectory(in temporaryDirectory: URL) throws -> TransportDirectory {
    let directoryURL = temporaryDirectory.appendingPathComponent(
      "\(transportDirectoryPrefix)\(getpid())-\(UUID().uuidString.lowercased())",
      isDirectory: true
    )
    guard mkdir(directoryURL.path, 0o700) == 0 else { throw Self.currentPOSIXError() }
    var info = stat()
    guard
      lstat(directoryURL.path, &info) == 0,
      info.st_uid == getuid(),
      info.st_mode & S_IFMT == S_IFDIR,
      info.st_mode & 0o777 == 0o700
    else {
      _ = rmdir(directoryURL.path)
      throw SupatermTerminalStartupError.invalidTemporaryDirectory
    }
    return TransportDirectory(
      directoryURL: directoryURL,
      cleanupToken: SupatermTerminalStartupCleanup(
        directoryURL: directoryURL,
        device: info.st_dev,
        inode: info.st_ino
      )
    )
  }

  public static func reapStaleTransports(
    temporaryDirectory: URL = URL(fileURLWithPath: "/private/tmp", isDirectory: true)
  ) {
    guard
      let urls = try? FileManager.default.contentsOfDirectory(
        at: temporaryDirectory,
        includingPropertiesForKeys: nil,
        options: [.skipsHiddenFiles]
      )
    else {
      return
    }
    for url in urls {
      guard let ownerProcessID = transportOwnerProcessID(url.lastPathComponent) else { continue }
      guard ownerProcessID != getpid(), kill(ownerProcessID, 0) == -1, errno == ESRCH else {
        continue
      }
      var info = stat()
      guard
        lstat(url.path, &info) == 0,
        info.st_uid == getuid(),
        info.st_mode & S_IFMT == S_IFDIR,
        info.st_mode & 0o777 == 0o700
      else {
        continue
      }
      try? FileManager.default.removeItem(at: url)
    }
  }

  private static func launcherScript(
    cliPath: String,
    argumentsPath: String,
    launcherPath: String
  ) -> String {
    let cli = SupatermShellCommand.escapedToken(cliPath)
    let arguments = SupatermShellCommand.escapedToken(argumentsPath)
    let launcher = SupatermShellCommand.escapedToken(launcherPath)
    return """
      #!/bin/sh
      /bin/rm -f -- \(launcher)
      exec \(cli) internal launch \(arguments)
      """
  }

  private static func scriptFileName(shellPath: String) -> String {
    switch URL(fileURLWithPath: shellPath).lastPathComponent.lowercased() {
    case "nu", "nushell":
      return "script.nu"
    default:
      return "script"
    }
  }

  private static func sourceCommand(scriptPath: String, shellPath: String) -> String {
    switch URL(fileURLWithPath: shellPath).lastPathComponent.lowercased() {
    case "csh", "tcsh", "fish", "nu", "nushell":
      return "source \(scriptPath)"
    case "elvish":
      return "eval (slurp <\(scriptPath))"
    default:
      return ". \(scriptPath)"
    }
  }

  private static func isExecutableFile(atPath path: String) -> Bool {
    guard path.hasPrefix("/") else { return false }
    var isDirectory = ObjCBool(false)
    return FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
      && !isDirectory.boolValue
      && FileManager.default.isExecutableFile(atPath: path)
  }

  private static func write(_ data: Data, to url: URL, permissions: mode_t) throws {
    let descriptor = open(
      url.path,
      O_WRONLY | O_CREAT | O_EXCL | O_NOFOLLOW | O_CLOEXEC,
      permissions
    )
    guard descriptor >= 0 else { throw currentPOSIXError() }
    defer { close(descriptor) }
    guard fchmod(descriptor, permissions) == 0 else { throw currentPOSIXError() }
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
        } else if result == -1, errno == EINTR {
          continue
        } else {
          throw currentPOSIXError()
        }
      }
    }
  }

  private static func currentPOSIXError() -> POSIXError {
    POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
  }

  private static func isShellSafePath(_ path: String) -> Bool {
    let characters = CharacterSet(
      charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789/._-"
    )
    return path.unicodeScalars.allSatisfy(characters.contains)
  }

  public static func transportOwnerProcessID(_ name: String) -> pid_t? {
    guard name.hasPrefix(transportDirectoryPrefix) else { return nil }
    let value = name.dropFirst(transportDirectoryPrefix.count)
    guard let separator = value.firstIndex(of: "-") else { return nil }
    guard
      let processID = pid_t(value[..<separator]),
      UUID(uuidString: String(value[value.index(after: separator)...])) != nil
    else {
      return nil
    }
    return processID
  }

  private static func validatedPayloadURL(_ path: String) -> URL? {
    guard path.hasPrefix("/") else { return nil }
    let url = URL(fileURLWithPath: path, isDirectory: false).standardized
    guard url.path == path, url.lastPathComponent == argumentsFileName else { return nil }
    let directoryURL = url.deletingLastPathComponent()
    guard
      transportOwnerProcessID(directoryURL.lastPathComponent) != nil,
      secureFile(atPath: directoryURL.path, type: S_IFDIR, permissions: 0o700)
    else {
      return nil
    }
    return url
  }

  private static func readAndRemovePayload(_ url: URL) -> Data? {
    let descriptor = open(url.path, O_RDONLY | O_NOFOLLOW | O_CLOEXEC)
    guard descriptor >= 0 else { return nil }
    defer { close(descriptor) }
    guard flock(descriptor, LOCK_EX | LOCK_NB) == 0 else { return nil }
    defer { _ = flock(descriptor, LOCK_UN) }
    var openedInfo = stat()
    guard
      fstat(descriptor, &openedInfo) == 0,
      openedInfo.st_uid == getuid(),
      openedInfo.st_mode & S_IFMT == S_IFREG,
      openedInfo.st_mode & 0o777 == 0o600,
      openedInfo.st_nlink == 1,
      openedInfo.st_size >= 0,
      openedInfo.st_size <= maximumArgumentsPayloadSize
    else {
      return nil
    }
    var linkedInfo = stat()
    guard
      lstat(url.path, &linkedInfo) == 0,
      linkedInfo.st_dev == openedInfo.st_dev,
      linkedInfo.st_ino == openedInfo.st_ino,
      unlink(url.path) == 0
    else {
      return nil
    }
    return read(descriptor: descriptor, expectedSize: Int(openedInfo.st_size))
  }

  private static func read(descriptor: Int32, expectedSize: Int) -> Data? {
    var data = Data()
    data.reserveCapacity(expectedSize)
    var buffer = [UInt8](repeating: 0, count: 64 * 1_024)
    while true {
      let remaining = maximumArgumentsPayloadSize + 1 - data.count
      guard remaining > 0 else { return nil }
      let count = buffer.withUnsafeMutableBytes { bytes in
        Darwin.read(descriptor, bytes.baseAddress, min(bytes.count, remaining))
      }
      if count > 0 {
        data.append(contentsOf: buffer.prefix(count))
        guard data.count <= maximumArgumentsPayloadSize else { return nil }
      } else if count == 0 {
        return data
      } else if errno != EINTR {
        return nil
      }
    }
  }

  private static func secureFile(atPath path: String, type: mode_t, permissions: mode_t) -> Bool {
    var info = stat()
    guard lstat(path, &info) == 0 else { return false }
    return info.st_uid == getuid()
      && info.st_mode & S_IFMT == type
      && info.st_mode & 0o777 == permissions
  }

  private struct TransportDirectory {
    let directoryURL: URL
    let cleanupToken: SupatermTerminalStartupCleanup
  }
}

public struct SupatermPreparedTerminalStartup: Sendable {
  public let initialInput: String
  public let cleanupToken: SupatermTerminalStartupCleanup?

  init(
    initialInput: String,
    cleanupToken: SupatermTerminalStartupCleanup?
  ) {
    self.initialInput = initialInput
    self.cleanupToken = cleanupToken
  }

  var cleanupDirectoryURL: URL? { cleanupToken?.directoryURL }
}

public struct SupatermTerminalStartupCleanup: Sendable {
  fileprivate let directoryURL: URL
  private let device: dev_t
  private let inode: ino_t

  fileprivate init(directoryURL: URL, device: dev_t, inode: ino_t) {
    self.directoryURL = directoryURL
    self.device = device
    self.inode = inode
  }

  public func cleanup() {
    var info = stat()
    guard
      lstat(directoryURL.path, &info) == 0,
      info.st_uid == getuid(),
      info.st_mode & S_IFMT == S_IFDIR,
      info.st_dev == device,
      info.st_ino == inode
    else {
      return
    }
    try? FileManager.default.removeItem(at: directoryURL)
  }
}

enum SupatermTerminalStartupError: Error {
  case invalidArguments
  case invalidCLIPath
  case invalidTemporaryDirectory
}
