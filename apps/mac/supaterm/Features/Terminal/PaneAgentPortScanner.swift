import Foundation
import SupatermSupport

nonisolated struct TerminalPanePortScanContext: Equatable, Sendable {
  let nativeProcessIdentities: Set<TerminalAgentProcessIdentity>
  let fallbackProcessIdentity: TerminalAgentProcessIdentity?
}

nonisolated private struct PaneAgentPortScanScope: Sendable {
  let roots: Set<TerminalAgentProcessIdentity>
  let processes: Set<TerminalAgentProcessIdentity>
}

@MainActor
final class PaneAgentPortScanner {
  typealias Delivery = @MainActor (UUID, [PaneAgentArtifact]) -> Void

  private struct Registration {
    let context: TerminalPanePortScanContext
    let foregroundProcessGroupID: @MainActor () -> Int32?
  }

  private let runner: TerminalAgentPanelCommandRunner
  private let interval: Duration
  private let captureProcessTree: @Sendable () -> TerminalAgentProcessTreeSnapshot
  private let isProcessCurrent: @Sendable (TerminalAgentProcessIdentity) -> Bool
  private var registrationsBySurfaceID: [UUID: Registration] = [:]
  private var artifactsBySurfaceID: [UUID: [PaneAgentArtifact]] = [:]
  private var scanTask: Task<Void, Never>?
  private var delivery: Delivery?

  init(
    runner: TerminalAgentPanelCommandRunner = .live,
    interval: Duration = .seconds(10),
    captureProcessTree: @escaping @Sendable () -> TerminalAgentProcessTreeSnapshot =
      TerminalAgentProcessTreeSnapshot.capture,
    isProcessCurrent: @escaping @Sendable (TerminalAgentProcessIdentity) -> Bool =
      TerminalAgentProcessInspector.isCurrent
  ) {
    self.runner = runner
    self.interval = interval
    self.captureProcessTree = captureProcessTree
    self.isProcessCurrent = isProcessCurrent
  }

  func update(
    surfaceID: UUID,
    context: TerminalPanePortScanContext,
    foregroundProcessGroupID: @escaping @MainActor () -> Int32? = { nil },
    deliver: @escaping Delivery
  ) {
    delivery = deliver
    registrationsBySurfaceID[surfaceID] = Registration(
      context: context,
      foregroundProcessGroupID: foregroundProcessGroupID
    )
    startLoop()
  }

  func clear(surfaceID: UUID, deliver: Delivery? = nil) {
    let wasTracked = registrationsBySurfaceID.removeValue(forKey: surfaceID) != nil
    let hadArtifacts = artifactsBySurfaceID.removeValue(forKey: surfaceID) != nil
    if wasTracked || hadArtifacts {
      (deliver ?? delivery)?(surfaceID, [])
    }
    stopLoopIfIdle()
  }

  func stop() {
    registrationsBySurfaceID.removeAll()
    artifactsBySurfaceID.removeAll()
    scanTask?.cancel()
    scanTask = nil
    delivery = nil
  }

  @discardableResult
  func scanOnce() async -> Bool {
    let registrationSnapshot = registrationsBySurfaceID
    guard !registrationSnapshot.isEmpty else {
      stopLoopIfIdle()
      return false
    }
    let contextsBySurfaceID = registrationSnapshot.mapValues(\.context)
    let foregroundProcessGroupIDsBySurfaceID: [UUID: Int32] =
      registrationSnapshot.compactMapValues { registration -> Int32? in
        guard !registration.context.nativeProcessIdentities.isEmpty else { return nil }
        return registration.foregroundProcessGroupID()
      }
    let portsBySurfaceID = await Self.scanPorts(
      contextsBySurfaceID: contextsBySurfaceID,
      foregroundProcessGroupIDsBySurfaceID: foregroundProcessGroupIDsBySurfaceID,
      captureProcessTree: captureProcessTree,
      isProcessCurrent: isProcessCurrent,
      runner: runner
    )
    var delivered = false
    let surfaceIDs = registrationSnapshot.keys.sorted { $0.uuidString < $1.uuidString }
    for surfaceID in surfaceIDs {
      guard
        registrationsBySurfaceID[surfaceID]?.context == registrationSnapshot[surfaceID]?.context
      else {
        continue
      }
      let artifacts = Self.artifacts(for: portsBySurfaceID[surfaceID] ?? [])
      guard artifactsBySurfaceID[surfaceID, default: []] != artifacts else { continue }
      artifactsBySurfaceID[surfaceID] = artifacts
      delivery?(surfaceID, artifacts)
      delivered = true
    }
    return delivered
  }

  private func startLoop() {
    guard scanTask == nil else { return }
    let interval = self.interval
    scanTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: interval)
        guard !Task.isCancelled else { return }
        await self?.scanOnce()
      }
    }
  }

  private func stopLoopIfIdle() {
    guard registrationsBySurfaceID.isEmpty else { return }
    scanTask?.cancel()
    scanTask = nil
  }

  @concurrent
  nonisolated static func scanPorts(
    contextsBySurfaceID: [UUID: TerminalPanePortScanContext],
    foregroundProcessGroupIDsBySurfaceID: [UUID: Int32],
    captureProcessTree: @Sendable () -> TerminalAgentProcessTreeSnapshot,
    isProcessCurrent: @Sendable (TerminalAgentProcessIdentity) -> Bool,
    runner: TerminalAgentPanelCommandRunner
  ) async -> [UUID: [Int]] {
    guard
      contextsBySurfaceID.values.contains(where: {
        !$0.nativeProcessIdentities.isEmpty || $0.fallbackProcessIdentity != nil
      })
    else {
      return [:]
    }
    let processTree = captureProcessTree()
    var scopesBySurfaceID: [UUID: [PaneAgentPortScanScope]] = [:]
    for (surfaceID, context) in contextsBySurfaceID {
      var scopes: [PaneAgentPortScanScope] = []
      let nativeScopes: [PaneAgentPortScanScope] = context.nativeProcessIdentities.compactMap {
        identity -> PaneAgentPortScanScope? in
        let processes = processTree.descendants(of: [identity])
        guard !processes.isEmpty else { return nil }
        return PaneAgentPortScanScope(roots: [identity], processes: processes)
      }
      scopes.append(contentsOf: nativeScopes)
      let nativeRoots = nativeScopes.reduce(into: Set<TerminalAgentProcessIdentity>()) {
        $0.formUnion($1.roots)
      }
      if !nativeRoots.isEmpty,
        let processGroupID = foregroundProcessGroupIDsBySurfaceID[surfaceID]
      {
        scopes.append(
          PaneAgentPortScanScope(
            roots: nativeRoots,
            processes: processTree.descendants(
              of: processTree.identities(inProcessGroup: processGroupID)
            )
          )
        )
      }
      if let fallbackProcessIdentity = context.fallbackProcessIdentity {
        let processes = processTree.descendants(of: [fallbackProcessIdentity])
        if !processes.isEmpty {
          scopes.append(
            PaneAgentPortScanScope(roots: [fallbackProcessIdentity], processes: processes)
          )
        }
      }
      scopesBySurfaceID[surfaceID] = scopes
    }
    let processIdentities = scopesBySurfaceID.values.joined().reduce(
      into: Set<TerminalAgentProcessIdentity>()
    ) {
      $0.formUnion($1.processes)
    }
    guard !processIdentities.isEmpty else {
      return [:]
    }
    let pids = processIdentities.map(\.processID).sorted().map(String.init).joined(separator: ",")
    guard
      let lsofResult = try? await runner.run(
        URL(fileURLWithPath: "/usr/sbin/lsof"),
        ["-nP", "-a", "-p", pids, "-iTCP", "-sTCP:LISTEN", "-Fpn"],
        nil
      )
    else {
      return [:]
    }
    let portsByPID = ports(fromLsofOutput: lsofResult.stdout)
    let currentProcessIdentities = Set(processIdentities.filter(isProcessCurrent))
    return scopesBySurfaceID.mapValues { scopes in
      var ports: Set<Int> = []
      for scope in scopes
      where !scope.roots.isDisjoint(with: currentProcessIdentities) {
        for identity in scope.processes.intersection(currentProcessIdentities) {
          ports.formUnion(portsByPID[Int(identity.processID)] ?? [])
        }
      }
      return ports.sorted()
    }
  }

  nonisolated static func artifacts(for ports: [Int]) -> [PaneAgentArtifact] {
    Array(Set(ports))
      .sorted()
      .compactMap { port in
        guard let url = URL(string: "http://localhost:\(port)") else { return nil }
        return PaneAgentArtifact(title: "localhost:\(port)", url: url)
      }
  }

  nonisolated static func ports(fromLsofOutput output: String) -> [Int: Set<Int>] {
    var result: [Int: Set<Int>] = [:]
    var currentPID: Int?
    for line in output.split(whereSeparator: \.isNewline) {
      guard let first = line.first else { continue }
      switch first {
      case "p":
        currentPID = Int(line.dropFirst())
      case "n":
        guard let pid = currentPID,
          let port = port(fromLsofName: String(line.dropFirst()))
        else {
          continue
        }
        result[pid, default: []].insert(port)
      default:
        break
      }
    }
    return result
  }

  nonisolated static func port(fromLsofName value: String) -> Int? {
    let localValue: String
    if let arrowRange = value.range(of: "->") {
      localValue = String(value[..<arrowRange.lowerBound])
    } else {
      localValue = value
    }
    guard let colonIndex = localValue.lastIndex(of: ":") else {
      return nil
    }
    let portText = localValue[localValue.index(after: colonIndex)...].prefix(while: \.isNumber)
    guard let port = Int(portText), port > 0, port <= 65535 else {
      return nil
    }
    return port
  }
}
