import Foundation

enum AgentTranscriptJSONValue: Equatable {
  case null
  case bool(Bool)
  case number(Double)
  case string(String)
  case array([Self])
  case object([String: Self])

  init?(_ value: Any) {
    switch value {
    case is NSNull:
      self = .null
    case let value as Bool:
      self = .bool(value)
    case let value as NSNumber:
      self = .number(value.doubleValue)
    case let value as String:
      self = .string(value)
    case let value as [Any]:
      self = .array(value.compactMap(Self.init))
    case let value as [String: Any]:
      self = .object(value.compactMapValues(Self.init))
    default:
      return nil
    }
  }

  var objectValue: [String: Self]? {
    guard case .object(let value) = self else { return nil }
    return value
  }

  var arrayValue: [Self]? {
    guard case .array(let value) = self else { return nil }
    return value
  }

  var stringValue: String? {
    guard case .string(let value) = self else { return nil }
    return value
  }

  var intValue: Int? {
    guard case .number(let value) = self else { return nil }
    return Int(exactly: value)
  }
}

typealias AgentTranscriptJSONObject = [String: AgentTranscriptJSONValue]

struct AgentTranscriptTailCursor: Equatable {
  var offset: UInt64
}

enum AgentTranscriptTailer {
  struct Tick {
    let cursor: AgentTranscriptTailCursor
    let objects: [AgentTranscriptJSONObject]
    let didReset: Bool
  }

  static func start(at path: String) -> Tick? {
    guard let data = read(path: path, from: 0) else { return nil }
    let (consumedBytes, objects) = parse(data)
    return Tick(
      cursor: AgentTranscriptTailCursor(offset: UInt64(consumedBytes)),
      objects: objects,
      didReset: false
    )
  }

  static func advance(
    _ cursor: AgentTranscriptTailCursor,
    at path: String
  ) -> Tick? {
    let fileURL = URL(fileURLWithPath: path)
    guard
      let values = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
      let fileSize = values.fileSize
    else {
      return nil
    }
    if UInt64(fileSize) < cursor.offset {
      guard let restarted = start(at: path) else { return nil }
      return Tick(cursor: restarted.cursor, objects: restarted.objects, didReset: true)
    }
    guard let data = read(path: path, from: cursor.offset) else { return nil }
    let (consumedBytes, objects) = parse(data)
    var updatedCursor = cursor
    updatedCursor.offset += UInt64(consumedBytes)
    return Tick(cursor: updatedCursor, objects: objects, didReset: false)
  }

  private static func read(path: String, from offset: UInt64) -> Data? {
    do {
      let handle = try FileHandle(forReadingFrom: URL(fileURLWithPath: path))
      defer { try? handle.close() }
      try handle.seek(toOffset: offset)
      return try handle.readToEnd() ?? Data()
    } catch {
      return nil
    }
  }

  private static func parse(_ data: Data) -> (Int, [AgentTranscriptJSONObject]) {
    guard let newlineIndex = data.lastIndex(of: 0x0A) else {
      return (0, [])
    }
    let completeData = data.prefix(through: newlineIndex)
    let objects = completeData.split(separator: 0x0A).compactMap { line in
      (try? JSONSerialization.jsonObject(with: Data(line)))
        .flatMap(AgentTranscriptJSONValue.init)?
        .objectValue
    }
    return (completeData.count, objects)
  }
}
