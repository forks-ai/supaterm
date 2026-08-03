import AppKit
import GhosttyKit
import SupatermCLIShared
import Testing

@testable import supaterm

@MainActor
struct GhosttySurfaceBridgeTests {
  @Test
  func openUrlRequestPreservesHTTPSURL() {
    let request = withOpenURLAction(url: "https://supaterm.com/changelog") {
      ghosttyOpenURLRequest(from: $0.action.open_url)
    }

    #expect(request?.kind == .unknown)
    #expect(request?.url.absoluteString == "https://supaterm.com/changelog")
    #expect(request?.url.isFileURL == false)
  }

  @Test
  func openUrlRequestTreatsTildePathAsFileURL() {
    let request = withOpenURLAction(url: "~/code/github.com/supabitapp/supaterm") {
      ghosttyOpenURLRequest(from: $0.action.open_url)
    }

    #expect(request?.url.isFileURL == true)
    #expect(request?.url.path == NSString(string: "~/code/github.com/supabitapp/supaterm").standardizingPath)
  }

  @Test
  func openUrlRequestTreatsPlainPathWithSpacesAsFileURL() {
    let request = withOpenURLAction(
      url: "/tmp/supa term/output.txt",
      kind: GHOSTTY_ACTION_OPEN_URL_KIND_TEXT
    ) {
      ghosttyOpenURLRequest(from: $0.action.open_url)
    }

    #expect(request?.kind == .text)
    #expect(request?.url.isFileURL == true)
    #expect(request?.url.path == "/tmp/supa term/output.txt")
  }

  @Test
  func inputChunksSplitControlScalarsIntoKeys() {
    #expect(
      ghosttyInputChunks("echo hello\r\u{03}tail\t\u{1B}\u{7F}\u{04}\u{0C}\u{1A}")
        == [
          .text("echo hello"),
          .key(.enter),
          .key(.ctrlC),
          .text("tail"),
          .key(.tab),
          .key(.escape),
          .key(.backspace),
          .key(.ctrlD),
          .key(.ctrlL),
          .key(.ctrlZ),
        ]
    )
  }

  @Test
  func emptySearchRestoresFindPasteboardNeedle() {
    let pasteboard = makePasteboard("restored")
    let bridge = GhosttySurfaceBridge(findPasteboard: pasteboard)

    withStartSearchAction(needle: "") { action in
      #expect(bridge.handleAction(target: surfaceTarget(), action: action) == false)
    }

    #expect(bridge.state.searchNeedle == "restored")
    #expect(bridge.state.searchFocusCount == 1)
    #expect(bridge.state.searchSelectionRequestCount == 1)
  }

  @Test
  func nonEmptySearchWritesFindPasteboardNeedle() {
    let pasteboard = makePasteboard("old")
    let bridge = GhosttySurfaceBridge(findPasteboard: pasteboard)

    withStartSearchAction(needle: "new") { action in
      #expect(bridge.handleAction(target: surfaceTarget(), action: action) == false)
    }

    #expect(bridge.state.searchNeedle == "new")
    #expect(pasteboard.string(forType: .string) == "new")
    #expect(bridge.state.searchSelectionRequestCount == 0)
  }

  @Test
  func changedSearchNeedleWritesFindPasteboard() {
    let pasteboard = makePasteboard()
    let bridge = GhosttySurfaceBridge(findPasteboard: pasteboard)
    bridge.state.searchNeedle = "before"

    bridge.setSearchNeedle("after")

    #expect(bridge.state.searchNeedle == "after")
    #expect(pasteboard.string(forType: .string) == "after")
  }

  @Test
  func activationRestoreUpdatesNeedleAndRequestsSelection() {
    let pasteboard = makePasteboard("before")
    let bridge = GhosttySurfaceBridge(findPasteboard: pasteboard)
    bridge.state.searchNeedle = "before"
    replacePasteboard(pasteboard, with: "after")

    bridge.restoreSearchNeedle()

    #expect(bridge.state.searchNeedle == "after")
    #expect(bridge.state.searchSelectionRequestCount == 1)
  }

  @Test
  func sharedFindPasteboardDoesNotShareLiveSearchState() {
    let pasteboard = makePasteboard()
    let firstBridge = GhosttySurfaceBridge(findPasteboard: pasteboard)
    let secondBridge = GhosttySurfaceBridge(findPasteboard: pasteboard)
    firstBridge.state.searchNeedle = "first"
    secondBridge.state.searchNeedle = "second"

    firstBridge.setSearchNeedle("updated")

    #expect(firstBridge.state.searchNeedle == "updated")
    #expect(secondBridge.state.searchNeedle == "second")
    #expect(pasteboard.string(forType: .string) == "updated")
  }

  @Test
  func openConfigUsesAppActionPerformer() {
    let app = NSApplication.shared
    let previousDelegate = app.delegate
    let delegate = GhosttyAppActionPerformerSpy()
    app.delegate = delegate
    defer {
      app.delegate = previousDelegate
    }

    let bridge = GhosttySurfaceBridge()
    let target = ghostty_target_s(tag: GHOSTTY_TARGET_SURFACE, target: ghostty_target_u())
    let action = ghostty_action_s(tag: GHOSTTY_ACTION_OPEN_CONFIG, action: ghostty_action_u())

    #expect(bridge.handleAction(target: target, action: action))
    #expect(delegate.openConfigCount == 1)
  }

  @Test
  func toggleCommandPaletteEmitsCallback() {
    let bridge = GhosttySurfaceBridge()
    var toggleCount = 0
    bridge.onCommandPaletteToggle = {
      toggleCount += 1
      return true
    }

    let target = ghostty_target_s(tag: GHOSTTY_TARGET_SURFACE, target: ghostty_target_u())
    let action = ghostty_action_s(tag: GHOSTTY_ACTION_TOGGLE_COMMAND_PALETTE, action: ghostty_action_u())

    #expect(bridge.handleAction(target: target, action: action))
    #expect(toggleCount == 1)
  }

  @Test
  func selectionChangedWithoutSurfaceViewIsHarmless() {
    let bridge = GhosttySurfaceBridge()
    let target = ghostty_target_s(tag: GHOSTTY_TARGET_SURFACE, target: ghostty_target_u())
    let action = ghostty_action_s(tag: GHOSTTY_ACTION_SELECTION_CHANGED, action: ghostty_action_u())

    #expect(bridge.handleAction(target: target, action: action) == false)
  }

  @Test
  func promptSurfaceTitleEmitsCallback() {
    let bridge = GhosttySurfaceBridge()
    var promptSurfaceTitle = 0
    var promptTabTitle = 0
    bridge.onPromptSurfaceTitle = {
      promptSurfaceTitle += 1
    }
    bridge.onPromptTabTitle = {
      promptTabTitle += 1
    }

    let target = ghostty_target_s(tag: GHOSTTY_TARGET_SURFACE, target: ghostty_target_u())
    var action = ghostty_action_s(tag: GHOSTTY_ACTION_PROMPT_TITLE, action: ghostty_action_u())
    action.action.prompt_title = GHOSTTY_PROMPT_TITLE_SURFACE

    #expect(bridge.handleAction(target: target, action: action) == false)
    #expect(promptSurfaceTitle == 1)
    #expect(promptTabTitle == 0)
  }

  @Test
  func promptTabTitleEmitsCallback() {
    let bridge = GhosttySurfaceBridge()
    var promptSurfaceTitle = 0
    var promptTabTitle = 0
    bridge.onPromptSurfaceTitle = {
      promptSurfaceTitle += 1
    }
    bridge.onPromptTabTitle = {
      promptTabTitle += 1
    }

    let target = ghostty_target_s(tag: GHOSTTY_TARGET_SURFACE, target: ghostty_target_u())
    var action = ghostty_action_s(tag: GHOSTTY_ACTION_PROMPT_TITLE, action: ghostty_action_u())
    action.action.prompt_title = GHOSTTY_PROMPT_TITLE_TAB

    #expect(bridge.handleAction(target: target, action: action) == false)
    #expect(promptSurfaceTitle == 0)
    #expect(promptTabTitle == 1)
  }

  @Test
  func setTitleDoesNotClearManualTitleOverride() {
    let bridge = GhosttySurfaceBridge()
    bridge.state.titleOverride = "Pinned"
    var emittedTitles: [String] = []
    bridge.onTitleChange = { emittedTitles.append($0) }

    let target = ghostty_target_s(tag: GHOSTTY_TARGET_SURFACE, target: ghostty_target_u())
    var action = ghostty_action_s(tag: GHOSTTY_ACTION_SET_TITLE, action: ghostty_action_u())
    let title = strdup("sleep 10")
    action.action.set_title.title = UnsafePointer(title)
    defer {
      free(title)
    }

    #expect(bridge.handleAction(target: target, action: action) == false)
    #expect(bridge.state.title == "sleep 10")
    #expect(bridge.state.titleOverride == "Pinned")
    #expect(emittedTitles.isEmpty)
  }

  @Test
  func openUrlReturnsHandledResult() {
    let bridge = GhosttySurfaceBridge()

    let target = ghostty_target_s(tag: GHOSTTY_TARGET_SURFACE, target: ghostty_target_u())
    withOpenURLAction(url: "not a valid url") { action in
      #expect(bridge.handleAction(target: target, action: action))
      #expect(bridge.state.openUrl == "not a valid url")
      #expect(bridge.state.openUrlKind == action.action.open_url.kind)
    }
  }

  @Test
  func unhealthyRendererExposesRendererUnavailableFailure() {
    let bridge = GhosttySurfaceBridge()
    let target = ghostty_target_s(tag: GHOSTTY_TARGET_SURFACE, target: ghostty_target_u())
    var action = ghostty_action_s(tag: GHOSTTY_ACTION_RENDERER_HEALTH, action: ghostty_action_u())
    action.action.renderer_health = GHOSTTY_RENDERER_HEALTH_UNHEALTHY

    #expect(bridge.handleAction(target: target, action: action) == false)
    #expect(bridge.state.failure == .rendererUnavailable)
  }

  @Test
  func healthyRendererClearsRendererUnavailableFailure() {
    let bridge = GhosttySurfaceBridge()
    let target = ghostty_target_s(tag: GHOSTTY_TARGET_SURFACE, target: ghostty_target_u())
    var action = ghostty_action_s(tag: GHOSTTY_ACTION_RENDERER_HEALTH, action: ghostty_action_u())
    action.action.renderer_health = GHOSTTY_RENDERER_HEALTH_UNHEALTHY
    _ = bridge.handleAction(target: target, action: action)

    action.action.renderer_health = GHOSTTY_RENDERER_HEALTH_HEALTHY
    #expect(bridge.handleAction(target: target, action: action) == false)
    #expect(bridge.state.failure == nil)
  }

  private func withOpenURLAction<T>(
    url: String,
    kind: ghostty_action_open_url_kind_e = GHOSTTY_ACTION_OPEN_URL_KIND_UNKNOWN,
    _ body: (ghostty_action_s) -> T
  ) -> T {
    var action = ghostty_action_s(tag: GHOSTTY_ACTION_OPEN_URL, action: ghostty_action_u())
    action.action.open_url.kind = kind
    guard let pointer = strdup(url) else {
      Issue.record("strdup failed")
      return body(action)
    }
    defer {
      free(pointer)
    }
    action.action.open_url.url = UnsafePointer(pointer)
    action.action.open_url.len = UInt(strlen(pointer))
    return body(action)
  }

  private func withStartSearchAction<T>(
    needle: String?,
    _ body: (ghostty_action_s) -> T
  ) -> T {
    var action = ghostty_action_s(tag: GHOSTTY_ACTION_START_SEARCH, action: ghostty_action_u())
    guard let needle else { return body(action) }
    return needle.withCString { pointer in
      action.action.start_search.needle = pointer
      return body(action)
    }
  }

  private func surfaceTarget() -> ghostty_target_s {
    ghostty_target_s(tag: GHOSTTY_TARGET_SURFACE, target: ghostty_target_u())
  }

  private func makePasteboard(_ string: String? = nil) -> NSPasteboard {
    let pasteboard = NSPasteboard(name: NSPasteboard.Name("supaterm-find-\(UUID().uuidString)"))
    replacePasteboard(pasteboard, with: string)
    return pasteboard
  }

  private func replacePasteboard(_ pasteboard: NSPasteboard, with string: String?) {
    pasteboard.clearContents()
    if let string {
      _ = pasteboard.setString(string, forType: .string)
    }
  }
}
