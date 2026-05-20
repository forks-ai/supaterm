import Foundation

public enum ConfirmQuitMode: String, Codable, CaseIterable, Equatable, Identifiable, Sendable {
  case auto
  case always
  case never

  public var id: String { rawValue }

  public var title: String {
    switch self {
    case .auto:
      return "Auto"
    case .always:
      return "Always"
    case .never:
      return "Never"
    }
  }
}
