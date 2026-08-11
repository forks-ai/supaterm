import Darwin
import Foundation

struct ProcessInvocation: Sendable, Equatable {
  let executablePath: String
  let arguments: [String]
  let terminalType: String?
}

struct ProcessEntry: Sendable, Equatable {
  let identity: TerminalAgentProcessIdentity
  let parentProcessID: pid_t
  let processGroupID: pid_t
  let foregroundProcessGroupID: pid_t
  let terminalDevice: dev_t
  let name: String

  var processID: pid_t {
    identity.processID
  }
}

struct ProcessTable: Sendable, Equatable {
  let entries: [ProcessEntry]

  static func snapshot() -> ProcessTable {
    var request: [Int32] = [CTL_KERN, KERN_PROC, KERN_PROC_ALL, 0]
    let stride = MemoryLayout<kinfo_proc>.stride
    var slack = 64

    while slack <= 4096 {
      var probedSize = 0
      guard sysctl(&request, 4, nil, &probedSize, nil, 0) == 0, probedSize > 0 else {
        return ProcessTable(entries: [])
      }

      var processes = [kinfo_proc](repeating: kinfo_proc(), count: probedSize / stride + slack)
      var readSize = processes.count * stride
      if sysctl(&request, 4, &processes, &readSize, nil, 0) == 0 {
        return ProcessTable(entries: processes.prefix(readSize / stride).compactMap(entry(from:)))
      }
      guard errno == ENOMEM else { return ProcessTable(entries: []) }
      slack *= 4
    }

    return ProcessTable(entries: [])
  }

  static func invocation(forProcessID processID: pid_t) -> ProcessInvocation? {
    var request: [Int32] = [CTL_KERN, KERN_PROCARGS2, processID]
    var probedSize = 0
    guard sysctl(&request, 3, nil, &probedSize, nil, 0) == 0, probedSize > 0 else { return nil }

    var buffer = [UInt8](repeating: 0, count: probedSize)
    var readSize = probedSize
    guard sysctl(&request, 3, &buffer, &readSize, nil, 0) == 0 else { return nil }

    return invocation(inProcessArguments: Array(buffer.prefix(readSize)))
  }

  static func invocation(inProcessArguments buffer: [UInt8]) -> ProcessInvocation? {
    let countWidth = MemoryLayout<UInt32>.size
    guard buffer.count > countWidth else { return nil }
    let count =
      Int(buffer[0]) | Int(buffer[1]) << 8 | Int(buffer[2]) << 16 | Int(buffer[3]) << 24

    var index = countWidth
    guard
      let executableBytes = nextBytes(in: buffer, index: &index),
      let executablePath = String(bytes: executableBytes, encoding: .utf8),
      !executablePath.isEmpty
    else {
      return nil
    }
    while index < buffer.count, buffer[index] == 0 { index += 1 }

    var arguments: [String] = []
    while arguments.count < count, index < buffer.count {
      guard
        let bytes = nextBytes(in: buffer, index: &index),
        let argument = String(bytes: bytes, encoding: .utf8)
      else {
        return nil
      }
      arguments.append(argument)
    }

    guard arguments.count == count else { return nil }

    let terminalTypePrefix = Array("TERM=".utf8)
    var terminalType: String?
    while index < buffer.count {
      while index < buffer.count, buffer[index] == 0 { index += 1 }
      guard index < buffer.count else { break }
      guard let variable = nextBytes(in: buffer, index: &index) else { return nil }
      if variable.starts(with: terminalTypePrefix) {
        terminalType = String(
          bytes: variable.dropFirst(terminalTypePrefix.count),
          encoding: .utf8
        )
      }
    }

    return ProcessInvocation(
      executablePath: executablePath,
      arguments: arguments,
      terminalType: terminalType
    )
  }

  private static func entry(from process: kinfo_proc) -> ProcessEntry? {
    guard
      let identity = TerminalAgentProcessIdentity(
        processID: process.kp_proc.p_pid,
        seconds: Int64(process.kp_proc.p_starttime.tv_sec),
        microseconds: Int64(process.kp_proc.p_starttime.tv_usec)
      )
    else {
      return nil
    }
    return ProcessEntry(
      identity: identity,
      parentProcessID: process.kp_eproc.e_ppid,
      processGroupID: process.kp_eproc.e_pgid,
      foregroundProcessGroupID: process.kp_eproc.e_tpgid,
      terminalDevice: process.kp_eproc.e_tdev,
      name: name(from: process)
    )
  }

  private static func name(from process: kinfo_proc) -> String {
    withUnsafeBytes(of: process.kp_proc.p_comm) { raw in
      String(bytes: raw.prefix { $0 != 0 }, encoding: .utf8) ?? ""
    }
  }

  private static func nextBytes(in buffer: [UInt8], index: inout Int) -> ArraySlice<UInt8>? {
    let start = index
    while index < buffer.count, buffer[index] != 0 { index += 1 }
    guard index < buffer.count else { return nil }
    defer { index += 1 }
    return buffer[start..<index]
  }
}
