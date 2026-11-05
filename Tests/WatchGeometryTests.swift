import XCTest
import SwiftUI
@testable import DuoTwitch

final class WatchGeometryTests: XCTestCase {
    func testBookKeepsEitherChatSideAndVideoOutOfDivision() {
        let size = CGSize(width: 1000, height: 750)
        let hinge = CGRect(x: 494, y: 0, width: 12, height: 750)
        for leading in [false, true] {
            let panes = WatchPaneGeometry(size: size, compact: false, division: hinge, mode: .slim, chatLeading: leading)
            XCTAssertFalse(panes.video.intersects(hinge))
            XCTAssertFalse(panes.chat.intersects(hinge))
            XCTAssertEqual(panes.chat.minX < panes.video.minX, leading)
            XCTAssertEqual(panes.video.width, 494)
        }
    }

    func testTabletopKeepsChatAndComposerBelowDivisionRegardlessOfSidePreference() {
        let hinge = CGRect(x: 0, y: 365, width: 1000, height: 20)
        for mode in [WatchMode.balanced, .slim] {
            for leading in [false, true] {
                let panes = WatchPaneGeometry(size: CGSize(width: 1000, height: 750), compact: false, division: hinge, mode: mode, chatLeading: leading)
                XCTAssertEqual(panes.video.maxY, hinge.minY)
                XCTAssertEqual(panes.chat.minY, hinge.maxY)
            }
        }
    }

    func testCompactAlwaysHasVideoAboveChatAndFullVideoRetainsAnEmptyChatSlot() {
        let size = CGSize(width: 390, height: 700)
        let compact = WatchPaneGeometry(size: size, compact: true, division: nil, mode: .balanced, chatLeading: true)
        XCTAssertLessThan(compact.video.maxY, compact.chat.minY)
        XCTAssertGreaterThan(compact.chat.height, 200)
        let full = WatchPaneGeometry(size: size, compact: true, division: nil, mode: .video, chatLeading: true)
        XCTAssertEqual(full.video.size, size)
        XCTAssertEqual(full.chat.width, 0)
        XCTAssertGreaterThan(full.chat.minX, size.width)
    }

    func testFullVideoStillAvoidsAnActiveHinge() {
        let size = CGSize(width: 1000, height: 750)
        let hinge = CGRect(x: 494, y: 0, width: 12, height: 750)
        let panes = WatchPaneGeometry(size: size, compact: false, division: hinge, mode: .video, chatLeading: false)
        XCTAssertFalse(panes.video.intersects(hinge))
        XCTAssertEqual(panes.video.maxX, hinge.minX)
    }
}
