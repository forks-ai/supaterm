import XCTest

final class SpaceLifecycleUITests: SupatermUITestCase {
  @MainActor
  func testCreateSwitchRenameAndDeleteSpace() async throws {
    await requireInitialSidebarTab()
    XCTAssertEqual(spaceDots.count, 1)

    try await createSpace(named: "UI Space")

    let didDisplayCreatedSpace = await waitForDisplayedSpace(named: "UI Space")
    XCTAssertTrue(didDisplayCreatedSpace)
    let didAddSpaceDot = await waitForSidebarElementCount(spaceDots, equals: 2)
    XCTAssertTrue(didAddSpaceDot)
    XCTAssertEqual(app.windows.count, 1)

    app.typeKey("1", modifierFlags: .control)

    let didDisplayInitialSpace = await waitForDisplayedSpace(named: "Space 1")
    XCTAssertTrue(didDisplayInitialSpace)

    let createdSpaceDot = spaceDot(named: "UI Space")
    if !createdSpaceDot.isHittable {
      app.typeKey("f", modifierFlags: [.control, .command])
    }
    let didMakeCreatedSpaceDotHittable = await wait(for: createdSpaceDot) {
      $0.exists && $0.isHittable
    }
    XCTAssertTrue(didMakeCreatedSpaceDotHittable)
    try require(createdSpaceDot).click()

    let didReturnToCreatedSpace = await waitForDisplayedSpace(named: "UI Space")
    XCTAssertTrue(didReturnToCreatedSpace)

    displayedSpace.click()
    let renameSpace = app.menuItems["Edit Space"]
    XCTAssertTrue(renameSpace.waitForExistence(timeout: 10))
    renameSpace.click()

    let nameField = app.textFields[
      SupatermUITestIdentifier.Accessibility.dialogSpaceName
    ]
    XCTAssertTrue(nameField.waitForExistence(timeout: 10))
    nameField.click()
    nameField.typeKey("a", modifierFlags: .command)
    nameField.typeText("Renamed UI Space")

    let greenSwatch = app.buttons[
      SupatermUITestIdentifier.Accessibility.dialogSpaceColorPrefix + "green"
    ]
    XCTAssertTrue(greenSwatch.waitForExistence(timeout: 10))
    greenSwatch.click()

    let confirm = app.buttons[
      SupatermUITestIdentifier.Accessibility.dialogConfirm
    ]
    XCTAssertTrue(confirm.waitForExistence(timeout: 10))
    confirm.click()

    let didRenameSpace = await waitForDisplayedSpace(named: "Renamed UI Space")
    XCTAssertTrue(didRenameSpace)
    XCTAssertFalse(spaceDot(named: "UI Space").exists)

    displayedSpace.click()
    let deleteSpace = app.menuItems["Delete Space"]
    XCTAssertTrue(deleteSpace.waitForExistence(timeout: 10))
    deleteSpace.click()

    let deleteSheet = app.sheets.firstMatch
    XCTAssertTrue(deleteSheet.waitForExistence(timeout: 10))
    let deleteTitle = deleteSheet.staticTexts["Delete Space \"Renamed UI Space\"?"]
    XCTAssertTrue(deleteTitle.waitForExistence(timeout: 10))
    let deleteButton = deleteSheet.buttons["Delete"]
    XCTAssertTrue(deleteButton.waitForExistence(timeout: 10))
    deleteButton.click()

    let didDisplayNeighborSpace = await waitForDisplayedSpace(named: "Space 1")
    XCTAssertTrue(didDisplayNeighborSpace)
    let didRemoveSpaceDot = await waitForSidebarElementCount(spaceDots, equals: 1)
    XCTAssertTrue(didRemoveSpaceDot)
    XCTAssertFalse(spaceDot(named: "Renamed UI Space").exists)
    XCTAssertEqual(app.windows.count, 1)
  }

  @MainActor
  private func createSpace(named name: String) async throws {
    try require(displayedSpace).click()
    let createSpace = try require(app.menuItems["New Space"])
    createSpace.click()

    let nameField = try require(
      app.textFields[SupatermUITestIdentifier.Accessibility.dialogSpaceName]
    )
    nameField.typeText(name)

    let confirm = try require(
      app.buttons[SupatermUITestIdentifier.Accessibility.dialogConfirm]
    )
    confirm.click()

    let didDismissEditor = await wait(for: nameField) { !$0.exists }
    XCTAssertTrue(didDismissEditor)
  }
}
