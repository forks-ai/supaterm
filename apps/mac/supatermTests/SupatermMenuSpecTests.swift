import AppKit
import Testing

@testable import supaterm

@MainActor
struct SupatermMenuSpecTests {
  @Test
  func menuItemSpecsHaveUniqueIdentifiers() {
    let controller = SupatermMenuController(registry: TerminalWindowRegistry())

    let identifiers = controller.menuItemSpecs().compactMap(\.id?.rawValue)

    #expect(identifiers.count == Set(identifiers).count)
    #expect(identifiers.count >= 60)
  }

  @Test
  func everySpecCarriesAnIdentifier() {
    let controller = SupatermMenuController(registry: TerminalWindowRegistry())

    #expect(controller.menuItemSpecs().allSatisfy { $0.id != nil })
  }

  @Test
  func slotSpecsCoverTabsAndSpaces() {
    let controller = SupatermMenuController(registry: TerminalWindowRegistry())
    let specs = controller.menuItemSpecs()

    let tabSlots = specs.filter {
      $0.id?.rawValue.hasPrefix("app.supabit.supaterm.tabs.select.") == true
    }
    let spaceSlots = specs.filter {
      $0.id?.rawValue.hasPrefix("app.supabit.supaterm.spaces.select.") == true
    }

    #expect(tabSlots.compactMap(\.slot) == Array(1...10))
    #expect(spaceSlots.compactMap(\.slot) == Array(1...10))
  }
}
