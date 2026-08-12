import AppKit
import ComposableArchitecture
import GhosttyKit
import Testing

@testable import SupatermCLIShared
@testable import SupatermTerminalCore
@testable import supaterm

@MainActor
struct TerminalCommandExecutorScreenshotTests {
  @Test
  func screenshotCapturesVisiblePaneAndRejectsHiddenPaneWithoutChangingSelection() async throws {
    initializeGhosttyForTests()
    let image = try #require(makeCaptureImage(width: 7, height: 5))
    let expectedRequest = try #require(
      TerminalWindowCaptureRequest(
        windowID: 42,
        geometry: TerminalWindowCaptureGeometry(
          windowFrame: CGRect(x: 0, y: 0, width: 100, height: 80),
          viewScreenFrame: CGRect(x: 10, y: 10, width: 70, height: 50),
          backingScaleFactor: 2
        )
      )
    )
    let capture = ScreenshotCaptureRecorder(image: image, request: expectedRequest)
    let registry = TerminalWindowRegistry()
    let commandExecutor = TerminalCommandExecutor(
      registry: registry,
      windowCaptureClient: capture.client
    )
    registry.commandExecutor = commandExecutor
    let (host, surface) = makeScreenshotHost()
    let selectedTabID = host.selectedTabID
    let selectedSurfaceID = surface.id
    let window = registerScreenshotWindow(host: host, registry: registry)

    let result = try await commandExecutor.screenshotPane(
      TerminalPaneTarget(paneID: surface.id)
    )

    let request = try #require(capture.request)
    let representation = try #require(NSBitmapImageRep(data: result.pngData))
    #expect(request == expectedRequest)
    #expect(result.target.paneID == surface.id)
    #expect(result.pngData.starts(with: [0x89, 0x50, 0x4E, 0x47]))
    #expect(representation.pixelsWide == 7)
    #expect(representation.pixelsHigh == 5)
    #expect(host.selectedTabID == selectedTabID)
    #expect(host.selectedSurfaceView?.id == selectedSurfaceID)

    capture.hidePane()
    await #expect(throws: TerminalControlError.screenshotPaneNotVisible) {
      try await commandExecutor.screenshotPane(TerminalPaneTarget(paneID: surface.id))
    }
    #expect(capture.captureCount == 1)
    withExtendedLifetime(window) {}
  }

  private func registerScreenshotWindow(
    host: TerminalHostState,
    registry: TerminalWindowRegistry
  ) -> NSWindow {
    let windowControllerID = UUID()
    registry.register(
      keyboardShortcutForAction: { _ in nil },
      windowControllerID: windowControllerID,
      store: Store(initialState: AppFeature.State()) {
        AppFeature()
      },
      terminal: host,
      requestConfirmedWindowClose: {}
    )
    let window = makeWindow()
    registry.updateWindow(window, for: windowControllerID)
    return window
  }

  private func makeScreenshotHost() -> (TerminalHostState, GhosttySurfaceView) {
    let runtime = GhosttyRuntime()
    let host = TerminalHostState(
      runtime: runtime,
      managesTerminalSurfaces: false,
      zmxClient: .noop,
      zmxSessionsEnabled: false
    )
    let tabID = host.spaceManager.tabCollection.createTab(title: "Screenshot")
    let surface = GhosttySurfaceView(
      runtime: runtime,
      tabID: tabID.rawValue,
      workingDirectory: nil,
      context: GHOSTTY_SURFACE_CONTEXT_TAB,
      surfaceFactory: { _, _ in nil }
    )
    host.trees[tabID] = SplitTree(view: surface)
    host.surfaces[surface.id] = surface
    host.focusHistoryByTab[tabID] = TerminalHostState.FocusHistory(current: surface.id)
    host.applySelectedTab(tabID, in: host.displayedSpaceID)
    return (host, surface)
  }

}

@MainActor
private final class ScreenshotCaptureRecorder {
  private let image: CGImage
  private var captureRequest: TerminalWindowCaptureRequest?
  private(set) var request: TerminalWindowCaptureRequest?
  private(set) var captureCount = 0
  lazy var client = TerminalWindowCaptureClient(
    requestForSurface: { [weak self] _ in self?.captureRequest },
    capture: { [weak self] request in
      self?.request = request
      self?.captureCount += 1
      return self?.image
    }
  )

  init(image: CGImage, request: TerminalWindowCaptureRequest?) {
    self.image = image
    self.captureRequest = request
  }

  func hidePane() {
    captureRequest = nil
  }
}
