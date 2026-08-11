import Foundation
import TOML

enum AgentDetectionRuleSetParser {
  static func parse(_ data: Data) throws -> AgentDetectionRuleSet {
    guard data.count <= AgentDetectionRuleSetValidator.maximumDocumentBytes else {
      throw AgentDetectionRuleSetError.documentTooLarge
    }

    do {
      let ruleSet = try TOMLDecoder().decode(AgentDetectionRuleSet.self, from: data)
      try AgentDetectionRuleSetValidator.validate(ruleSet)
      return ruleSet
    } catch let error as AgentDetectionRuleSetError {
      throw error
    } catch {
      throw AgentDetectionRuleSetError.invalidDocument(error.localizedDescription)
    }
  }
}

enum AgentDetectionRuleSetError: Error, Equatable, LocalizedError, Sendable {
  case documentTooLarge
  case invalidDocument(String)
  case invalidValue(String)
  case duplicateValue(String)
  case limitExceeded(String)
  case invalidRegularExpression(String)

  var errorDescription: String? {
    switch self {
    case .documentTooLarge:
      "Agent detection rules exceed 256 KiB."
    case .invalidDocument(let detail):
      "Agent detection rules are not valid TOML: \(detail)"
    case .invalidValue(let path):
      "Agent detection rules contain an invalid value at \(path)."
    case .duplicateValue(let path):
      "Agent detection rules contain a duplicate value at \(path)."
    case .limitExceeded(let path):
      "Agent detection rules exceed the limit at \(path)."
    case .invalidRegularExpression(let path):
      "Agent detection rules contain an invalid regular expression at \(path)."
    }
  }
}
