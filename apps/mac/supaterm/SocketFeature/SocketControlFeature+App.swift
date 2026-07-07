import Foundation
import SupatermCLIShared

extension SocketControlFeature {
  func appResponseResult(
    for request: SupatermSocketRequest,
    socketRequestExecutor: SocketRequestExecutor
  ) async throws -> SupatermSocketResponse? {
    if let response = try await appSettingsResponseResult(
      for: request,
      socketRequestExecutor: socketRequestExecutor
    ) {
      return response
    }

    switch request.method {
    case SupatermSocketMethod.appOnboarding:
      let result = try await socketRequestExecutor.executeApp(.onboardingSnapshot)
      guard case .onboardingSnapshot(let snapshot) = result else {
        throw SocketExecutorError.unexpectedResult
      }
      guard let snapshot else {
        throw SocketRequestError.onboardingUnavailable
      }
      return try .ok(id: request.id, encodableResult: snapshot)

    case SupatermSocketMethod.appDebug:
      let payload = try request.decodeParams(SupatermDebugRequest.self)
      let result = try await socketRequestExecutor.executeApp(.debugSnapshot(payload))
      guard case .debugSnapshot(let snapshot) = result else {
        throw SocketExecutorError.unexpectedResult
      }
      return try .ok(id: request.id, encodableResult: snapshot)

    case SupatermSocketMethod.appTree:
      let result = try await socketRequestExecutor.executeApp(.treeSnapshot)
      guard case .treeSnapshot(let snapshot) = result else {
        throw SocketExecutorError.unexpectedResult
      }
      return try .ok(id: request.id, encodableResult: snapshot)

    case SupatermSocketMethod.appQuit:
      let result = try await socketRequestExecutor.executeApp(.quit)
      guard case .quit = result else {
        throw SocketExecutorError.unexpectedResult
      }
      return .ok(id: request.id)

    default:
      return nil
    }
  }

  private func appSettingsResponseResult(
    for request: SupatermSocketRequest,
    socketRequestExecutor: SocketRequestExecutor
  ) async throws -> SupatermSocketResponse? {
    switch request.method {
    case SupatermSocketMethod.appSettingsList:
      let payload = try request.decodeParams(SupatermSettingsListRequest.self)
      let result = try await socketRequestExecutor.executeApp(.settingsList(payload))
      guard case .settingsList(let settingsResult) = result else {
        throw SocketExecutorError.unexpectedResult
      }
      return try .ok(id: request.id, encodableResult: settingsResult)

    case SupatermSocketMethod.appSettingsGet:
      let payload = try request.decodeParams(SupatermSettingsGetRequest.self)
      let result = try await socketRequestExecutor.executeApp(.settingsGet(payload))
      guard case .settingsGet(let settingsResult) = result else {
        throw SocketExecutorError.unexpectedResult
      }
      return try .ok(id: request.id, encodableResult: settingsResult)

    case SupatermSocketMethod.appSettingsSet:
      let payload = try request.decodeParams(SupatermSettingsSetRequest.self)
      let result = try await socketRequestExecutor.executeApp(.settingsSet(payload))
      guard case .settingsSet(let settingsResult) = result else {
        throw SocketExecutorError.unexpectedResult
      }
      return try .ok(id: request.id, encodableResult: settingsResult)

    case SupatermSocketMethod.appSettingsReset:
      let payload = try request.decodeParams(SupatermSettingsResetRequest.self)
      let result = try await socketRequestExecutor.executeApp(.settingsReset(payload))
      guard case .settingsReset(let settingsResult) = result else {
        throw SocketExecutorError.unexpectedResult
      }
      return try .ok(id: request.id, encodableResult: settingsResult)

    default:
      return nil
    }
  }
}
