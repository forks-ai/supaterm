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
