import XCTest
@testable import ClipboardDrawer

final class ProOCRErrorTests: XCTestCase {
    func testOCRErrorDescriptionsAreUserFriendly() {
        XCTAssertEqual(
            OCRError.invalidImage.localizedDescription,
            "Clipwell could not read this image. Try copying a PNG, JPG, or screenshot image."
        )
        XCTAssertEqual(
            OCRError.noTextFound.localizedDescription,
            "No readable text was found in the image."
        )
    }

    func testScreenshotErrorDescriptionsAreUserFriendly() {
        XCTAssertEqual(
            ScreenshotError.cancelled.localizedDescription,
            "Screenshot OCR was cancelled."
        )
        XCTAssertEqual(
            ScreenshotError.missingCaptureFile.localizedDescription,
            "Clipwell could not read the captured screenshot. Please try again."
        )
    }
}
