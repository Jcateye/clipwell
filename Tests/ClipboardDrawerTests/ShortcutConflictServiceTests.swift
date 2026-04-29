import Carbon
@testable import ClipboardDrawer
import XCTest

final class ShortcutConflictServiceTests: XCTestCase {
    func testRejectsModifierOnlyShortcut() {
        let result = ShortcutConflictService().validate(
            shortcut: AppShortcut(keyCode: UInt32.max, modifierFlags: UInt32(optionKey)),
            for: .toggleDrawer,
            existing: [:]
        )

        XCTAssertTrue(result.isHardConflict)
        XCTAssertEqual(result.message, "Shortcut must include a non-modifier key.")
    }

    func testWarnsForReservedShortcut() {
        let result = ShortcutConflictService().validate(
            shortcut: AppShortcut(keyCode: 49, modifierFlags: UInt32(cmdKey)),
            for: .toggleDrawer,
            existing: [:]
        )

        XCTAssertFalse(result.isHardConflict)
        XCTAssertNotNil(result.warning)
    }
}
