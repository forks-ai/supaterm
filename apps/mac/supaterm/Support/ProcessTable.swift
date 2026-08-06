import Darwin
import Foundation

public struct ProcessEntry: Sendable, Equatable {
  public let processID: pid_t
  public let parentProcessID: pid_t
  public let processGroupID: pid_t
  public let foregroundProcessGroupID: pid_t
  public let terminalDevice: dev_t
  public let name: String

  public init(
    processID: pid_t,
    parentProcessID: pid_t,
    processGroupID: pid_t,
    foregroundProcessGroupID: pid_t,
    terminalDevice: dev_t,
    name: String
  ) {
    self.processID = processID
    self.parentProcessID = parentProcessID
    self.processGroupID = processGroupID
    self.foregroundProcessGroupID = foregroundProcessGroupID
    self.terminalDevice = terminalDevice
    self.name = name
  }
}

public struct ProcessTable: Sendable, Equatable {
  public let entries: [ProcessEntry]

  public init(entries: [ProcessEntry]) {
    self.entries = entries
  }

  public func children(of processID: pid_t) -> [ProcessEntry] {
    entries.filter { $0.parentProcessID == processID }
  }

  public func foregroundGroup(onTerminalOf entry: ProcessEntry) -> [ProcessEntry] {
    entries.filter {
      $0.terminalDevice == entry.terminalDevice
        && $0.processGroupID == entry.foregroundProcessGroupID
    }
  }

  public static func snapshot() -> ProcessTable {
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
        return ProcessTable(entries: processes.prefix(readSize / stride).map(entry(from:)))
      }
      guard errno == ENOMEM else { return ProcessTable(entries: []) }
      slack *= 4
    }

    return ProcessTable(entries: [])
  }

  public static func arguments(forProcessID processID: pid_t) -> [String]? {
    var request: [Int32] = [CTL_KERN, KERN_PROCARGS2, processID]
    var probedSize = 0
    guard sysctl(&request, 3, nil, &probedSize, nil, 0) == 0, probedSize > 0 else { return nil }

    var buffer = [UInt8](repeating: 0, count: probedSize)
    var readSize = probedSize
    guard sysctl(&request, 3, &buffer, &readSize, nil, 0) == 0 else { return nil }

    return arguments(inProcessArguments: Array(buffer.prefix(readSize)))
  }

  public static func arguments(inProcessArguments buffer: [UInt8]) -> [String]? {
    let countWidth = MemoryLayout<UInt32>.size
    guard buffer.count > countWidth else { return nil }
    let count =
      Int(buffer[0]) | Int(buffer[1]) << 8 | Int(buffer[2]) << 16 | Int(buffer[3]) << 24

    var index = countWidth
    while index < buffer.count, buffer[index] != 0 { index += 1 }
    while index < buffer.count, buffer[index] == 0 { index += 1 }

    var arguments: [String] = []
    while arguments.count < count, index < buffer.count {
      var end = index
      while end < buffer.count, buffer[end] != 0 { end += 1 }
      guard let argument = String(bytes: buffer[index..<end], encoding: .utf8) else { return nil }
      arguments.append(argument)
      index = end + 1
    }

    return arguments.count == count ? arguments : nil
  }

  private static func entry(from process: kinfo_proc) -> ProcessEntry {
    ProcessEntry(
      processID: process.kp_proc.p_pid,
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
}
