import XCTest
import SwiftUI
@testable import DuoTwitch

final class WatchGeometryTests: XCTestCase {
    func testShortLandscapeReservesAnUnscaledPlayerAndSideControlsAlongsideChat() {
        for mode in [WatchMode.balanced, .slim] {
            let panes = WatchPaneGeometry(size: CGSize(width: 750, height: 304), compact: true,
                division: nil, mode: mode, chatLeading: false)
            XCTAssertGreaterThanOrEqual(panes.video.width - 64, 400)
            XCTAssertEqual(panes.video.height, 304)
            XCTAssertEqual(panes.chat.width, mode.defaultChatExtent)
            XCTAssertFalse(panes.video.intersects(panes.chat))
        }
    }

    func testEligiblePortraitReservesPlayerAndChromeWithoutEliminatingChat() {
        for mode in [WatchMode.balanced, .slim] {
            for height in [604.0, 605.0, 740.0] {
                let panes = WatchPaneGeometry(size: CGSize(width: 402, height: height), compact: true,
                                              division: nil, mode: mode, chatLeading: false)
                XCTAssertEqual(panes.video.height, height - mode.defaultChatExtent - 12)
                XCTAssertEqual(panes.chat.height, mode.defaultChatExtent)
            }
        }
    }

    func testChatLayoutsKeepAPositiveVideoAllocationAcrossWidthAndHeightBoundaries() {
        for compact in [false, true] {
            for mode in [WatchMode.balanced, .slim] {
                for width in [400.0, 402, 550, 640, 641, 650, 900] {
                    for height in [364.0, 390, 604, 605, 700] {
                        let size = CGSize(width: width, height: height)
                        let panes = WatchPaneGeometry(size: size, compact: compact, division: nil, mode: mode, chatLeading: true)
                        XCTAssertGreaterThan(panes.video.width, 0)
                        XCTAssertGreaterThan(panes.video.height, 0)
                        XCTAssertTrue(CGRect(origin: .zero, size: size).contains(panes.video))
                        XCTAssertFalse(panes.video.intersects(panes.chat))
                    }
                }
            }
        }
    }

    func testOpenPortraitDefaultsToLargestVideoWithChatBelowAndCanResize() {
        let size = CGSize(width: 800, height: 1100)
        let initial = WatchPaneGeometry(size: size, compact: false, division: nil, mode: .balanced, chatLeading: false)
        XCTAssertEqual(initial.chat.height, 240)
        XCTAssertEqual(initial.video.height, 848)
        XCTAssertEqual(initial.chat.minY, initial.video.maxY + 12)
        let bigger = WatchPaneGeometry(size: size, compact: false, division: nil, mode: .balanced,
            chatLeading: false, placement: .below, chatHeight: 400)
        XCTAssertEqual(bigger.chat.height, 400)
        XCTAssertEqual(bigger.video.height, 688)
    }

    func testLandscapeChatResizesOnEitherSideDownToOnePointOfVideo() {
        for leading in [false, true] {
            for desired in [0.0, 240, 340, 10000] {
                let panes = WatchPaneGeometry(size: CGSize(width: 1000, height: 700), compact: false,
                    division: nil, mode: .balanced, chatLeading: leading, chatWidth: desired)
                XCTAssertEqual(panes.chat.width, min(max(1, desired), 987))
                XCTAssertGreaterThanOrEqual(panes.video.width, 1)
                XCTAssertEqual(panes.video.height, 700)
                XCTAssertEqual(panes.chat.minX < panes.video.minX, leading)
                XCTAssertFalse(panes.video.intersects(panes.chat))
            }
        }
    }

    func testExplicitPlacementAndExtremeSizesRespectUserSizeAndHinge() {
        let size = CGSize(width: 1000, height: 900)
        let below = WatchPaneGeometry(size: size, compact: false, division: nil, mode: .balanced,
            chatLeading: true, placement: .below, chatHeight: 10000)
        XCTAssertEqual(below.video.height, 1)
        XCTAssertEqual(below.chat.minY, 13)
        let beside = WatchPaneGeometry(size: CGSize(width: 800, height: 1100), compact: false,
            division: nil, mode: .balanced, chatLeading: false, placement: .beside, chatWidth: 300)
        XCTAssertEqual(beside.chat.width, 300)
        XCTAssertEqual(beside.video.height, 1100)
        let hinge = CGRect(x: 494, y: 0, width: 12, height: 900)
        let folded = WatchPaneGeometry(size: size, compact: false, division: hinge, mode: .balanced,
            chatLeading: true, placement: .below, chatWidth: 10000, chatHeight: 10000)
        XCTAssertEqual(folded.video.minX, hinge.maxX)
        XCTAssertEqual(folded.chat.maxX, hinge.minX)
    }

    func testSlimHasADistinctDefaultChatAllocationBesideAndBelow() {
        for placement in [WatchChatPlacement.beside, .below] {
            let size = CGSize(width: 1000, height: 900)
            let balanced = WatchPaneGeometry(size: size, compact: false, division: nil,
                mode: .balanced, chatLeading: false, placement: placement)
            let slim = WatchPaneGeometry(size: size, compact: false, division: nil,
                mode: .slim, chatLeading: false, placement: placement)
            if placement == .beside {
                XCTAssertLessThan(slim.chat.width, balanced.chat.width)
                XCTAssertGreaterThan(slim.video.width, balanced.video.width)
            } else {
                XCTAssertLessThan(slim.chat.height, balanced.chat.height)
                XCTAssertGreaterThan(slim.video.height, balanced.video.height)
            }
        }
    }

    func testSmallPresentationKeepsSupportedBoundedLogicalViewport() {
        for available in [CGSize(width: 382, height: 280), CGSize(width: 96, height: 120),
                          CGSize(width: 500, height: 80), CGSize(width: 1, height: 700),
                          CGSize(width: 900, height: 1)] {
            let viewport = WatchVideoViewport(available: available)
            XCTAssertTrue(viewport.visible)
            XCTAssertGreaterThanOrEqual(viewport.size.width, 400)
            XCTAssertGreaterThanOrEqual(viewport.size.height, 300)
            XCTAssertLessThanOrEqual(viewport.size.width, 1600)
            XCTAssertLessThanOrEqual(viewport.size.height, 1600)
            XCTAssertGreaterThan(viewport.scale, 0)
            XCTAssertLessThanOrEqual(viewport.size.width * viewport.scale, available.width + 0.001)
            XCTAssertLessThanOrEqual(viewport.size.height * viewport.scale, available.height + 0.001)
        }
        let large = WatchVideoViewport(available: CGSize(width: 800, height: 600))
        XCTAssertEqual(large.scale, 0.625)
        XCTAssertEqual(large.size, CGSize(width: 1280, height: 720))
        for empty in [CGSize.zero, CGSize(width: 100, height: 0), CGSize(width: CGFloat.nan, height: 40)] {
            let viewport = WatchVideoViewport(available: empty)
            XCTAssertFalse(viewport.visible)
            XCTAssertEqual(viewport.scale, 0)
        }
    }

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
