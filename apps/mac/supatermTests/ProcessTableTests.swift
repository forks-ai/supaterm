import Darwin
import Foundation
import Testing

@testable import SupatermSupport

struct ProcessTableTests {
  private static func processArguments(count: Int, executablePath: String, arguments: [String])
    -> [UInt8]
  {
    var buffer: [UInt8] = []
    let value = UInt32(count)
    buffer.append(contentsOf: [
      UInt8(value & 0xFF),
      UInt8((value >> 8) & 0xFF),
      UInt8((value >> 16) & 0xFF),
      UInt8((value >> 24) & 0xFF),
    ])
    buffer.append(contentsOf: Array(executablePath.utf8))
    buffer.append(contentsOf: [0, 0, 0])
    for argument in arguments {
      buffer.append(contentsOf: Array(argument.utf8))
      buffer.append(0)
    }
    return buffer
  }

  @Test
  func parsesArgumentVectorAfterExecutablePathPadding() throws {
    let parsed = ProcessTable.arguments(
      inProcessArguments: Self.processArguments(
        count: 3,
        executablePath: "/usr/bin/ssh",
        arguments: ["ssh", "-p", "2222"]
      )
    )

    #expect(try #require(parsed) == ["ssh", "-p", "2222"])
  }

  @Test
  func rejectsTruncatedArgumentVectors() {
    #expect(
      ProcessTable.arguments(
        inProcessArguments: Self.processArguments(
          count: 4,
          executablePath: "/usr/bin/ssh",
          arguments: ["ssh", "example.com"]
        )
      ) == nil
    )
    #expect(ProcessTable.arguments(inProcessArguments: [1, 0]) == nil)
  }

  @Test
  func snapshotSeesTheCurrentProcess() throws {
    let table = ProcessTable.snapshot()
    let current = try #require(table.entries.first { $0.processID == getpid() })

    #expect(current.parentProcessID == getppid())
    #expect(current.processGroupID == getpgrp())
  }

  @Test
  func readsArgumentsOfTheCurrentProcess() throws {
    let arguments = try #require(ProcessTable.arguments(forProcessID: getpid()))

    #expect(!arguments.isEmpty)
  }

  @Test
  func selectsChildrenAndForegroundGroupMembers() {
    let leader = ProcessEntry(
      processID: 10,
      parentProcessID: 1,
      processGroupID: 10,
      foregroundProcessGroupID: 20,
      terminalDevice: 5,
      name: "login"
    )
    let foreground = ProcessEntry(
      processID: 20,
      parentProcessID: 10,
      processGroupID: 20,
      foregroundProcessGroupID: 20,
      terminalDevice: 5,
      name: "ssh"
    )
    let otherTerminal = ProcessEntry(
      processID: 30,
      parentProcessID: 10,
      processGroupID: 20,
      foregroundProcessGroupID: 20,
      terminalDevice: 6,
      name: "ssh"
    )
    let table = ProcessTable(entries: [leader, foreground, otherTerminal])

    #expect(table.children(of: 10) == [foreground, otherTerminal])
    #expect(table.foregroundGroup(onTerminalOf: leader) == [foreground])
  }
}
