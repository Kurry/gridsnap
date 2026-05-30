import XCTest
@testable import GridSnap

class GridSnapTests: XCTestCase {

    // MARK: - bestLayout: aspect-ratio-aware grid

    private let landscape = (w: CGFloat(1920), h: CGFloat(1080))  // 16:9
    private let laptop    = (w: CGFloat(1440), h: CGFloat(900))   // 1.6:1

    func testBestLayoutOneWindow() {
        let (c, r) = MultiWindowManager.bestLayout(count: 1, screenWidth: landscape.w, screenHeight: landscape.h)
        XCTAssertEqual(c, 1); XCTAssertEqual(r, 1)
    }

    func testBestLayoutTwoWindows() {
        // 2 windows side-by-side beats 1 column of 2 rows on a landscape screen
        let (c, r) = MultiWindowManager.bestLayout(count: 2, screenWidth: landscape.w, screenHeight: landscape.h)
        XCTAssertEqual(c, 2); XCTAssertEqual(r, 1)
    }

    func testBestLayoutFourWindows2x2() {
        // 2×2 has 0 blanks and squarish tiles — better than 3×2 (2 blanks) or 4×1 (tall tiles)
        let (c, r) = MultiWindowManager.bestLayout(count: 4, screenWidth: landscape.w, screenHeight: landscape.h)
        XCTAssertEqual(c, 2); XCTAssertEqual(r, 2)
    }

    func testBestLayoutSixWindows() {
        // 3×2 on landscape: near-square tiles, 0 blanks
        let (c, r) = MultiWindowManager.bestLayout(count: 6, screenWidth: landscape.w, screenHeight: landscape.h)
        XCTAssertEqual(c, 3); XCTAssertEqual(r, 2)
    }

    func testBestLayoutSixWindowsOnLaptop() {
        // Same expectation on a laptop-size screen
        let (c, r) = MultiWindowManager.bestLayout(count: 6, screenWidth: laptop.w, screenHeight: laptop.h)
        XCTAssertEqual(c, 3); XCTAssertEqual(r, 2)
    }

    func testBestLayoutSevenWindowsAvoidsNineGrid() {
        // Old ceil(sqrt(7))=3 → 3×3 with 2 blanks.
        // New algorithm should prefer 4×2 (1 blank, more square tiles on landscape).
        let (c, r) = MultiWindowManager.bestLayout(count: 7, screenWidth: landscape.w, screenHeight: landscape.h)
        XCTAssertEqual(c * r - 7, 1, "should have exactly 1 blank cell, not 2")
        XCTAssertEqual(c, 4); XCTAssertEqual(r, 2)
    }

    func testBestLayoutNineWindows() {
        // Perfect 3×3 — 0 blanks and reasonably square tiles
        let (c, r) = MultiWindowManager.bestLayout(count: 9, screenWidth: landscape.w, screenHeight: landscape.h)
        XCTAssertEqual(c, 3); XCTAssertEqual(r, 3)
    }

    func testBestLayoutNoBlanksPreferred() {
        // For counts that divide evenly, there should be no blank cells
        for count in [1, 2, 3, 4, 6, 8, 9, 12] {
            let (c, r) = MultiWindowManager.bestLayout(count: count, screenWidth: landscape.w, screenHeight: landscape.h)
            let blanks = c * r - count
            XCTAssertEqual(blanks, 0, "count=\(count) → \(c)×\(r) should have 0 blanks")
        }
    }

    func testBestLayoutCoversAllWindows() {
        for count in 1...12 {
            let (c, r) = MultiWindowManager.bestLayout(count: count, screenWidth: landscape.w, screenHeight: landscape.h)
            XCTAssertGreaterThanOrEqual(c * r, count, "grid must hold all \(count) windows")
        }
    }

    // MARK: - bestLayout: target-aspect awareness

    func testBestLayoutDefaultStillSquare() {
        // Omitting targetAspect must reproduce the old square-tile behavior exactly.
        let (c, r) = MultiWindowManager.bestLayout(count: 4, screenWidth: landscape.w, screenHeight: landscape.h)
        XCTAssertEqual(c, 2); XCTAssertEqual(r, 2)
    }

    func testBestLayoutTerminalAspectPrefersMoreColumns() {
        // 6 wide-ish terminal windows (~1.6:1). Square scoring gives 3×2; matching the
        // terminals' landscape ratio should favor stacking more rows so each tile stays wide.
        let square   = MultiWindowManager.bestLayout(count: 6, screenWidth: landscape.w, screenHeight: landscape.h, targetAspect: 1)
        let terminal = MultiWindowManager.bestLayout(count: 6, screenWidth: landscape.w, screenHeight: landscape.h, targetAspect: 1.6)
        XCTAssertEqual(square.columns, 3)
        // A wide target should never pick a layout that makes tiles narrower than the square choice.
        XCTAssertLessThanOrEqual(terminal.columns, square.columns)
    }

    func testBestLayoutTallWindowsPreferMoreColumns() {
        // Portrait windows (aspect 0.6) should push toward more columns so tiles stay tall/narrow.
        let square = MultiWindowManager.bestLayout(count: 6, screenWidth: landscape.w, screenHeight: landscape.h, targetAspect: 1)
        let tall   = MultiWindowManager.bestLayout(count: 6, screenWidth: landscape.w, screenHeight: landscape.h, targetAspect: 0.6)
        XCTAssertGreaterThanOrEqual(tall.columns, square.columns)
    }

    func testMedianAspectBasic() {
        let frames = [
            CGRect(x: 0, y: 0, width: 800, height: 500),  // 1.6
            CGRect(x: 0, y: 0, width: 800, height: 500),  // 1.6
            CGRect(x: 0, y: 0, width: 900, height: 600),  // 1.5
        ]
        XCTAssertEqual(MultiWindowManager.medianAspect(of: frames), 1.6, accuracy: 0.001)
    }

    func testMedianAspectIgnoresDegenerateFrames() {
        let frames = [
            CGRect.null,
            CGRect(x: 0, y: 0, width: 0, height: 500),
            CGRect(x: 0, y: 0, width: 1000, height: 500), // 2.0
        ]
        XCTAssertEqual(MultiWindowManager.medianAspect(of: frames), 2.0, accuracy: 0.001)
    }

    func testMedianAspectEmptyDefaultsToSquare() {
        XCTAssertEqual(MultiWindowManager.medianAspect(of: []), 1.0, accuracy: 0.001)
    }

    func testMedianAspectClampsOutliers() {
        // A 50:1 window must not collapse the target — clamp keeps it usable.
        let frames = [CGRect(x: 0, y: 0, width: 5000, height: 100)] // aspect 50
        XCTAssertEqual(MultiWindowManager.medianAspect(of: frames), 3.0, accuracy: 0.001)
    }

    // MARK: - Tile layout math

    private let screen = CGRect(x: 0, y: 0, width: 1920, height: 1080)

    func testTileRectsEmptyCount() {
        XCTAssertTrue(MultiWindowManager.tileRects(count: 0, in: screen, gap: 8).isEmpty)
    }

    func testTileRectsOneWindow() {
        let rects = MultiWindowManager.tileRects(count: 1, in: screen, gap: 8)
        XCTAssertEqual(rects.count, 1)
        // 1×1: 0 inner gaps → tileW = 1920, tileH = 1080; tile fills the whole screen
        XCTAssertEqual(rects[0].width,  1920)
        XCTAssertEqual(rects[0].height, 1080)
        XCTAssertEqual(rects[0].minX, screen.minX)
        XCTAssertEqual(rects[0].minY, screen.minY)
    }

    func testTileRectsTwoWindows() {
        let rects = MultiWindowManager.tileRects(count: 2, in: screen, gap: 8)
        XCTAssertEqual(rects.count, 2)
        // 2×1: 1 inner gap → tileW = floor((1920 − 8) / 2) = 956
        XCTAssertEqual(rects[0].width, 956)
        XCTAssertEqual(rects[1].width, 956)
        XCTAssertEqual(rects[0].height, rects[1].height)
    }

    func testTileRectsFourWindowsGrid() {
        let rects = MultiWindowManager.tileRects(count: 4, in: screen, gap: 8)
        XCTAssertEqual(rects.count, 4)
        // bestLayout → 2×2; all widths and heights should be equal
        XCTAssertEqual(rects[0].width,  rects[1].width)
        XCTAssertEqual(rects[0].height, rects[2].height)
    }

    func testTileRectsSevenWindowsHasOnlyOneBlank() {
        // Old algorithm: 3×3 → 2 blanks. New: 4×2 → 1 blank.
        let (c, r) = MultiWindowManager.bestLayout(count: 7, screenWidth: screen.width, screenHeight: screen.height)
        XCTAssertEqual(c * r - 7, 1)
        let rects = MultiWindowManager.tileRects(count: 7, in: screen, gap: 8)
        XCTAssertEqual(rects.count, 7)
    }

    func testTileRectsNoOverlap() {
        for count in [2, 3, 4, 5, 6, 7, 9] {
            let rects = MultiWindowManager.tileRects(count: count, in: screen, gap: 8)
            for i in 0..<rects.count {
                for j in (i+1)..<rects.count {
                    let ix = rects[i].intersection(rects[j])
                    XCTAssertTrue(
                        ix.isNull || ix.width <= 0 || ix.height <= 0,
                        "windows \(i) and \(j) overlap for count=\(count)"
                    )
                }
            }
        }
    }

    func testTileRectsAllFitInScreen() {
        for count in [1, 2, 3, 4, 6, 7, 9] {
            let rects = MultiWindowManager.tileRects(count: count, in: screen, gap: 8)
            for rect in rects {
                XCTAssertGreaterThanOrEqual(rect.minX, screen.minX, "count=\(count): left edge outside screen")
                XCTAssertGreaterThanOrEqual(rect.minY, screen.minY, "count=\(count): bottom edge outside screen")
                XCTAssertLessThanOrEqual(rect.maxX, screen.maxX + 1, "count=\(count): right edge outside screen")
                XCTAssertLessThanOrEqual(rect.maxY, screen.maxY + 1, "count=\(count): top edge outside screen")
            }
        }
    }

    func testTileRectsGapsRespected() {
        let gap: CGFloat = 10
        // 4 windows → 2×2 grid
        let rects = MultiWindowManager.tileRects(count: 4, in: screen, gap: gap)
        // rects[0]=top-left, rects[1]=top-right (same row)
        let hGap = rects[1].minX - rects[0].maxX
        XCTAssertEqual(hGap, gap, accuracy: 1, "horizontal gap should be \(gap)px")
        // rects[2]=bottom-left (next row, lower y in macOS normal coords)
        let vGap = rects[0].minY - rects[2].maxY
        XCTAssertEqual(vGap, gap, accuracy: 1, "vertical gap should be \(gap)px")
    }

    func testTileRectsPixelAligned() {
        let rects = MultiWindowManager.tileRects(count: 6, in: screen, gap: 8)
        for rect in rects {
            XCTAssertEqual(rect.width,  floor(rect.width),  "width must be integer pixels")
            XCTAssertEqual(rect.height, floor(rect.height), "height must be integer pixels")
        }
    }

    func testTileRectsZeroGap() {
        let rects = MultiWindowManager.tileRects(count: 4, in: screen, gap: 0)
        XCTAssertEqual(rects.count, 4)
        let hGap = rects[1].minX - rects[0].maxX
        XCTAssertEqual(hGap, 0, accuracy: 1)
    }

    // MARK: - spatialOrder: pure window ordering

    func testSpatialOrderSingleWindow() {
        let order = MultiWindowManager.spatialOrder(frames: [CGRect(x: 0, y: 0, width: 500, height: 400)])
        XCTAssertEqual(order, [0])
    }

    func testSpatialOrderBasicTwoByTwo() {
        // 4 frames in a 2×2 grid, passed in reverse spatial order (AX coords: Y=0 at top, Y down).
        let frames: [CGRect] = [
            CGRect(x: 600, y: 200, width: 300, height: 200), // 0 → bottom-right
            CGRect(x: 100, y:   0, width: 300, height: 200), // 1 → top-left
            CGRect(x: 600, y:   0, width: 300, height: 200), // 2 → top-right
            CGRect(x: 100, y: 200, width: 300, height: 200), // 3 → bottom-left
        ]
        // Expected: top-left(1), top-right(2), bottom-left(3), bottom-right(0)
        let order = MultiWindowManager.spatialOrder(frames: frames)
        XCTAssertEqual(order, [1, 2, 3, 0])
    }

    func testSpatialOrderMacBookSixWindowsShuffled() {
        // Reproduces the ordering bug on the user's MacBook (1728 px wide, AX coords).
        // Six windows already tiled in a 3×2 grid, but submitted in a shuffled order
        // that triggered wrong slot assignment before the fix.
        // Frame values derived from tileRects(count:6, in:(0,71,1728,1013), gap:8) → AX conversion.
        let frames: [CGRect] = [
            CGRect(x: 1154, y:  41, width: 565, height: 494), // 0 → top-right
            CGRect(x:  581, y: 543, width: 565, height: 494), // 1 → bottom-center
            CGRect(x:    8, y:  41, width: 565, height: 494), // 2 → top-left
            CGRect(x: 1154, y: 543, width: 565, height: 494), // 3 → bottom-right
            CGRect(x:  581, y:  41, width: 565, height: 494), // 4 → top-center
            CGRect(x:    8, y: 543, width: 565, height: 494), // 5 → bottom-left
        ]
        let order = MultiWindowManager.spatialOrder(frames: frames)
        XCTAssertEqual(order, [2, 4, 0, 5, 1, 3],
                       "expected top-left→top-center→top-right→bottom-left→bottom-center→bottom-right")
    }

    func testSpatialOrderCoversAllIndices() {
        // Returned slice must be a permutation of the input indices — no duplicates, no missing.
        let frames: [CGRect] = [
            CGRect(x: 200, y: 100, width: 400, height: 300),
            CGRect(x: 200, y: 500, width: 400, height: 300),
            CGRect(x: 700, y: 100, width: 400, height: 300),
            CGRect(x: 700, y: 500, width: 400, height: 300),
            CGRect(x: 100, y: 900, width: 400, height: 300),
        ]
        let order = MultiWindowManager.spatialOrder(frames: frames)
        XCTAssertEqual(Set(order), Set(frames.indices))
    }

    // MARK: - CGRect screenFlipped coordinate transform

    func testScreenFlippedRoundTrip() {
        let rect = CGRect(x: 100, y: 200, width: 400, height: 300)
        XCTAssertEqual(rect.screenFlipped.screenFlipped, rect)
    }

    func testScreenFlippedNullRect() {
        XCTAssertTrue(CGRect.null.screenFlipped.isNull)
    }

    func testScreenFlippedPreservesSize() {
        let rect = CGRect(x: 50, y: 100, width: 800, height: 600)
        let flipped = rect.screenFlipped
        XCTAssertEqual(flipped.width,  rect.width)
        XCTAssertEqual(flipped.height, rect.height)
    }

    // MARK: - ScreenDetection percentage math

    func testPercentageFullyContained() {
        let pct = ScreenDetection().percentageOf(
            CGRect(x: 100, y: 100, width: 200, height: 200),
            withinFrameOfScreen: CGRect(x: 0, y: 0, width: 1920, height: 1080)
        )
        XCTAssertEqual(pct, 1.0, accuracy: 0.001)
    }

    func testPercentageHalfOverlap() {
        let pct = ScreenDetection().percentageOf(
            CGRect(x: 500, y: 0, width: 1000, height: 1000),
            withinFrameOfScreen: CGRect(x: 0, y: 0, width: 1000, height: 1000)
        )
        XCTAssertEqual(pct, 0.5, accuracy: 0.001)
    }

    func testPercentageNoOverlap() {
        let pct = ScreenDetection().percentageOf(
            CGRect(x: 600, y: 0, width: 200, height: 200),
            withinFrameOfScreen: CGRect(x: 0, y: 0, width: 500, height: 500)
        )
        XCTAssertEqual(pct, 0.0, accuracy: 0.001)
    }
}
