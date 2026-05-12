import Darwin
import Foundation
import SupatermCLIShared

struct TerminalAgentPresenceStore {
  struct Instance: Equatable, Sendable {
    let activity: TerminalHostState.AgentActivity
    let hasStatus: Bool
    let revision: Int
    let surfaceID: UUID
    let surfaceIndex: Int
  }

  private struct Key: Hashable, Sendable {
    let surfaceID: UUID
    let agent: SupatermAgentKind
  }

  private struct Record: Equatable, Sendable {
    var sessionIDs: Set<String> = []
    var processIDs: Set<Int32> = []
    var activity: TerminalHostState.AgentActivity?
    var revision: Int
  }

  private var records: [Key: Record] = [:]
  private var nextRevision = 0

  @discardableResult
  mutating func register(
    agent: SupatermAgentKind,
    surfaceID: UUID,
    sessionID: String?,
    processID: Int32?
  ) -> Bool {
    let key = Key(surfaceID: surfaceID, agent: agent)
    let isNewRecord = records[key] == nil
    var record = records[key] ?? Record(revision: nextRevision)
    let original = record
    insert(sessionID: sessionID, processID: processID, into: &record)
    if record != original || isNewRecord {
      record.revision = advanceRevision()
      records[key] = record
      return true
    }
    return false
  }

  @discardableResult
  mutating func setActivity(
    _ activity: TerminalHostState.AgentActivity,
    surfaceID: UUID,
    sessionID: String?,
    processID: Int32?
  ) -> Bool {
    let key = Key(surfaceID: surfaceID, agent: activity.kind)
    let isNewRecord = records[key] == nil
    var record = records[key] ?? Record(revision: nextRevision)
    let original = record
    insert(sessionID: sessionID, processID: processID, into: &record)
    record.activity = activity
    if record != original || isNewRecord {
      record.revision = advanceRevision()
      records[key] = record
      return true
    }
    return false
  }

  @discardableResult
  mutating func remove(
    agent: SupatermAgentKind,
    surfaceID: UUID,
    sessionID: String?,
    processID: Int32?
  ) -> Bool {
    let key = Key(surfaceID: surfaceID, agent: agent)
    guard var record = records[key] else { return false }
    let original = record
    if let sessionID = normalizedSessionID(sessionID) {
      record.sessionIDs.remove(sessionID)
    }
    if let processID = normalizedProcessID(processID) {
      record.processIDs.remove(processID)
    }
    if record.sessionIDs.isEmpty && (record.processIDs.isEmpty || processID == nil) {
      records.removeValue(forKey: key)
      return true
    }
    if record != original {
      record.revision = advanceRevision()
      records[key] = record
      return true
    }
    return false
  }

  @discardableResult
  mutating func removeSurface(_ surfaceID: UUID) -> Bool {
    let keys = records.keys.filter { $0.surfaceID == surfaceID }
    guard !keys.isEmpty else { return false }
    for key in keys {
      records.removeValue(forKey: key)
    }
    return true
  }

  @discardableResult
  mutating func pruneDeadProcesses(
    isProcessAlive: (Int32) -> Bool = TerminalAgentPresenceStore.isProcessAlive
  ) -> Set<UUID> {
    var changedSurfaceIDs: Set<UUID> = []
    for (key, record) in records where !record.processIDs.isEmpty {
      let liveProcessIDs = Set(record.processIDs.filter(isProcessAlive))
      guard liveProcessIDs != record.processIDs else { continue }
      changedSurfaceIDs.insert(key.surfaceID)
      if liveProcessIDs.isEmpty {
        records.removeValue(forKey: key)
      } else {
        var nextRecord = record
        nextRecord.processIDs = liveProcessIDs
        nextRecord.revision = advanceRevision()
        records[key] = nextRecord
      }
    }
    return changedSurfaceIDs
  }

  func badgeInstances(across surfaceIDs: [UUID]) -> [Instance] {
    instances(across: surfaceIDs, includeUnstatused: true).sorted {
      let lhsPriority = Self.statusPriority($0.activity.phase)
      let rhsPriority = Self.statusPriority($1.activity.phase)
      if lhsPriority != rhsPriority {
        return lhsPriority > rhsPriority
      }
      if $0.activity.kind.rawValue != $1.activity.kind.rawValue {
        return $0.activity.kind.rawValue < $1.activity.kind.rawValue
      }
      if $0.surfaceIndex != $1.surfaceIndex {
        return $0.surfaceIndex < $1.surfaceIndex
      }
      return $0.revision > $1.revision
    }
  }

  func statusInstances(for surfaceID: UUID, surfaceIndex: Int) -> [Instance] {
    instances(across: [surfaceID], includeUnstatused: false)
      .map {
        Instance(
          activity: $0.activity,
          hasStatus: $0.hasStatus,
          revision: $0.revision,
          surfaceID: $0.surfaceID,
          surfaceIndex: surfaceIndex
        )
      }
      .sorted {
        if $0.activity.kind.rawValue != $1.activity.kind.rawValue {
          return $0.activity.kind.rawValue < $1.activity.kind.rawValue
        }
        return $0.revision > $1.revision
      }
  }

  func detailActivity(for surfaceID: UUID?) -> TerminalHostState.AgentActivity? {
    guard let surfaceID else { return nil }
    return statusInstances(for: surfaceID, surfaceIndex: 0)
      .max { lhs, rhs in
        let lhsPriority = Self.statusPriority(lhs.activity.phase)
        let rhsPriority = Self.statusPriority(rhs.activity.phase)
        if lhsPriority != rhsPriority {
          return lhsPriority < rhsPriority
        }
        return lhs.revision < rhs.revision
      }?
      .activity
  }

  private func instances(across surfaceIDs: [UUID], includeUnstatused: Bool) -> [Instance] {
    var surfaceIndexes: [UUID: Int] = [:]
    for (index, surfaceID) in surfaceIDs.enumerated() where surfaceIndexes[surfaceID] == nil {
      surfaceIndexes[surfaceID] = index
    }

    return records.compactMap { key, record in
      guard let surfaceIndex = surfaceIndexes[key.surfaceID] else { return nil }
      if !includeUnstatused && record.activity == nil { return nil }
      return Instance(
        activity: record.activity ?? TerminalHostState.AgentActivity(kind: key.agent, phase: .idle),
        hasStatus: record.activity != nil,
        revision: record.revision,
        surfaceID: key.surfaceID,
        surfaceIndex: surfaceIndex
      )
    }
  }

  private mutating func advanceRevision() -> Int {
    let revision = nextRevision
    nextRevision += 1
    return revision
  }

  private func insert(sessionID: String?, processID: Int32?, into record: inout Record) {
    if let sessionID = normalizedSessionID(sessionID) {
      record.sessionIDs.insert(sessionID)
    }
    if let processID = normalizedProcessID(processID) {
      record.processIDs.insert(processID)
    }
  }

  private func normalizedSessionID(_ sessionID: String?) -> String? {
    guard let sessionID = sessionID?.trimmingCharacters(in: .whitespacesAndNewlines),
      !sessionID.isEmpty
    else {
      return nil
    }
    return sessionID
  }

  private func normalizedProcessID(_ processID: Int32?) -> Int32? {
    guard let processID, processID > 0 else { return nil }
    return processID
  }

  private static func statusPriority(_ phase: TerminalHostState.AgentActivityPhase) -> Int {
    TerminalHostState.agentActivityPriority(phase)
  }

  nonisolated static func isProcessAlive(_ processID: Int32) -> Bool {
    processID > 0 && kill(pid_t(processID), 0) == 0
  }
}
