import Foundation

struct AgentDetectionHTTPResponse: Sendable {
  let url: URL
  let statusCode: Int
  let data: Data
  let etag: String?
}

typealias AgentDetectionHTTPFetch =
  @Sendable (URLRequest, Int) async throws -> AgentDetectionHTTPResponse

private enum AgentDetectionLiveHTTP {
  @concurrent
  static func fetch(
    _ request: URLRequest,
    maximumBytes: Int
  ) async throws -> AgentDetectionHTTPResponse {
    let (bytes, response) = try await URLSession.shared.bytes(for: request)
    guard let response = response as? HTTPURLResponse, let responseURL = response.url else {
      throw AgentDetectionRuleUpdaterError.nonHTTPResponse
    }
    if response.expectedContentLength > maximumBytes {
      throw AgentDetectionRuleUpdaterError.responseTooLarge(maximumBytes: maximumBytes)
    }

    var data = Data()
    if response.expectedContentLength > 0 {
      data.reserveCapacity(min(Int(response.expectedContentLength), maximumBytes))
    }
    for try await byte in bytes {
      guard data.count < maximumBytes else {
        throw AgentDetectionRuleUpdaterError.responseTooLarge(maximumBytes: maximumBytes)
      }
      data.append(byte)
    }
    return AgentDetectionHTTPResponse(
      url: responseURL,
      statusCode: response.statusCode,
      data: data,
      etag: response.value(forHTTPHeaderField: "ETag")
    )
  }
}

public enum AgentDetectionRuleUpdateResult: Equatable, Sendable {
  case updated(generation: UInt64)
  case unchanged(generation: UInt64)
  case notModified(generation: UInt64)
}

enum AgentDetectionRuleUpdaterError: Error, Equatable, LocalizedError, Sendable {
  case nonHTTPResponse
  case responseTooLarge(maximumBytes: Int)
  case invalidStatusCode(Int)
  case missingETag
  case unexpectedResponseOrigin
  case unexpectedNotModified

  var errorDescription: String? {
    switch self {
    case .nonHTTPResponse:
      "The agent detection update did not receive an HTTP response."
    case .responseTooLarge(let maximumBytes):
      "The agent detection update exceeds \(maximumBytes) bytes."
    case .invalidStatusCode(let statusCode):
      "The agent detection update returned HTTP status \(statusCode)."
    case .missingETag:
      "The agent detection rule response has no ETag."
    case .unexpectedResponseOrigin:
      "The agent detection rule response came from another origin."
    case .unexpectedNotModified:
      "The agent detection update returned not modified without a valid cache."
    }
  }
}

public actor AgentDetectionRuleUpdater {
  private let repository: AgentDetectionRuleRepository
  private let rulesURL: URL
  private let fetch: AgentDetectionHTTPFetch
  private var inFlightUpdate: Task<AgentDetectionRuleUpdateResult, any Error>?

  public init(
    repository: AgentDetectionRuleRepository,
    rulesURL: URL
  ) {
    self.repository = repository
    self.rulesURL = rulesURL
    fetch = { request, maximumBytes in
      try await AgentDetectionLiveHTTP.fetch(
        request,
        maximumBytes: maximumBytes
      )
    }
  }

  init(
    repository: AgentDetectionRuleRepository,
    rulesURL: URL,
    fetch: @escaping AgentDetectionHTTPFetch
  ) {
    self.repository = repository
    self.rulesURL = rulesURL
    self.fetch = fetch
  }

  public func update() async throws -> AgentDetectionRuleUpdateResult {
    if let inFlightUpdate {
      return try await inFlightUpdate.value
    }

    let update = Task(priority: .utility) { [repository, rulesURL, fetch] in
      try await Self.performUpdate(
        repository: repository,
        rulesURL: rulesURL,
        fetch: fetch
      )
    }
    inFlightUpdate = update

    do {
      let result = try await withTaskCancellationHandler {
        try await update.value
      } onCancel: {
        update.cancel()
      }
      inFlightUpdate = nil
      return result
    } catch {
      inFlightUpdate = nil
      throw error
    }
  }

  @concurrent
  private static func performUpdate(
    repository: AgentDetectionRuleRepository,
    rulesURL: URL,
    fetch: AgentDetectionHTTPFetch
  ) async throws -> AgentDetectionRuleUpdateResult {
    let cachedEntry = await repository.cachedEntryForRevalidation
    try Task.checkCancellation()
    var rulesRequest = URLRequest(
      url: rulesURL,
      cachePolicy: .reloadIgnoringLocalCacheData
    )
    if let cachedEntry {
      rulesRequest.setValue(cachedEntry.etag, forHTTPHeaderField: "If-None-Match")
    }

    let rulesResponse = try await fetch(
      rulesRequest,
      AgentDetectionRuleSetValidator.maximumDocumentBytes
    )
    try Task.checkCancellation()
    guard sameOrigin(rulesURL, rulesResponse.url) else {
      throw AgentDetectionRuleUpdaterError.unexpectedResponseOrigin
    }
    guard rulesResponse.data.count <= AgentDetectionRuleSetValidator.maximumDocumentBytes else {
      throw AgentDetectionRuleUpdaterError.responseTooLarge(
        maximumBytes: AgentDetectionRuleSetValidator.maximumDocumentBytes
      )
    }
    if rulesResponse.statusCode == 304 {
      guard cachedEntry != nil else {
        throw AgentDetectionRuleUpdaterError.unexpectedNotModified
      }
      return .notModified(generation: await repository.generation)
    }
    guard rulesResponse.statusCode == 200 else {
      throw AgentDetectionRuleUpdaterError.invalidStatusCode(rulesResponse.statusCode)
    }
    guard let etag = rulesResponse.etag else {
      throw AgentDetectionRuleUpdaterError.missingETag
    }
    try AgentDetectionRuleCache.validateETag(etag)

    try Task.checkCancellation()
    switch try await repository.install(
      rules: rulesResponse.data,
      etag: etag
    ) {
    case .updated(let generation):
      return .updated(generation: generation)
    case .unchanged(let generation):
      return .unchanged(generation: generation)
    }
  }

  private static func sameOrigin(_ requestedURL: URL, _ responseURL: URL) -> Bool {
    guard
      requestedURL.scheme?.lowercased() == "https",
      responseURL.scheme?.lowercased() == requestedURL.scheme?.lowercased(),
      responseURL.host?.lowercased() == requestedURL.host?.lowercased()
    else {
      return false
    }
    return effectivePort(responseURL) == effectivePort(requestedURL)
  }

  private static func effectivePort(_ url: URL) -> Int? {
    url.port ?? (url.scheme?.lowercased() == "https" ? 443 : nil)
  }
}
