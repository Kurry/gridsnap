//
//  ScreenDetection.swift
//  GridSnap
//
//  Created by Kurry Tran on 6/12/19.
//  Copyright © 2026 Kurry Tran. All rights reserved.
//

import Cocoa

class ScreenDetection {

    func detectScreens(using frontmostWindowElement: AccessibilityElement?) -> UsableScreens? {
        let screens = NSScreen.screens
        guard let firstScreen = screens.first else { return nil }

        if screens.count == 1 {
            return UsableScreens(currentScreen: firstScreen, numScreens: 1, screensOrdered: [firstScreen])
        }

        let screensOrdered = order(screens: screens)
        guard let sourceScreen = screenContaining(frontmostWindowElement?.frame ?? CGRect.zero, screens: screensOrdered) else {
            let adjacentScreens = AdjacentScreens(prev: firstScreen, next: firstScreen)
            return UsableScreens(currentScreen: firstScreen, adjacentScreens: adjacentScreens, numScreens: screens.count, screensOrdered: screensOrdered)
        }

        let adjacentScreens = adjacent(toFrameOfScreen: sourceScreen.frame, screens: screensOrdered)
        return UsableScreens(currentScreen: sourceScreen, adjacentScreens: adjacentScreens, numScreens: screens.count, screensOrdered: screensOrdered)
    }

    func detectScreensAtCursor() -> UsableScreens? {
        let screens = NSScreen.screens
        if screens.count == 1 {
            return detectScreens(using: nil)
        }

        let screensOrdered = order(screens: screens)

        guard let cursorScreen = screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) })
        else {
            return detectScreens(using: nil)
        }

        let adjacentScreens = adjacent(toFrameOfScreen: cursorScreen.frame, screens: screensOrdered)
        return UsableScreens(currentScreen: cursorScreen, adjacentScreens: adjacentScreens, numScreens: screens.count, screensOrdered: screensOrdered)
    }

    func screenContaining(_ rect: CGRect, screens: [NSScreen]) -> NSScreen? {
        var result: NSScreen? = NSScreen.main
        var largestPercentageOfRectWithinFrameOfScreen: CGFloat = 0.0
        for currentScreen in screens {
            let currentFrameOfScreen = NSRectToCGRect(currentScreen.frame)
            let normalizedRect: CGRect = rect.screenFlipped
            if currentFrameOfScreen.contains(normalizedRect) {
                result = currentScreen
                break
            }
            let percentageOfRectWithinCurrentFrameOfScreen: CGFloat = percentageOf(normalizedRect, withinFrameOfScreen: currentFrameOfScreen)
            if percentageOfRectWithinCurrentFrameOfScreen > largestPercentageOfRectWithinFrameOfScreen {
                largestPercentageOfRectWithinFrameOfScreen = percentageOfRectWithinCurrentFrameOfScreen
                result = currentScreen
            }
        }
        return result
    }

    func percentageOf(_ rect: CGRect, withinFrameOfScreen frameOfScreen: CGRect) -> CGFloat {
        let intersectionOfRectAndFrameOfScreen: CGRect = rect.intersection(frameOfScreen)
        var result: CGFloat = 0.0
        if !intersectionOfRectAndFrameOfScreen.isNull {
            result = computeAreaOfRect(rect: intersectionOfRectAndFrameOfScreen) / computeAreaOfRect(rect: rect)
        }
        return result
    }

    func adjacent(toFrameOfScreen frameOfScreen: CGRect, screens: [NSScreen]) -> AdjacentScreens? {
        if screens.count == 2 {
            let otherScreen = screens.first(where: { screen in
                let frame = NSRectToCGRect(screen.frame)
                return !frame.equalTo(frameOfScreen)
            })
            if let otherScreen = otherScreen {
                return AdjacentScreens(prev: otherScreen, next: otherScreen)
            }
        } else if screens.count > 2 {
            let currentScreenIndex = screens.firstIndex(where: { screen in
                let frame = NSRectToCGRect(screen.frame)
                return frame.equalTo(frameOfScreen)
            })
            if let currentScreenIndex = currentScreenIndex {
                let nextIndex = currentScreenIndex == screens.count - 1 ? 0 : currentScreenIndex + 1
                let prevIndex = currentScreenIndex == 0 ? screens.count - 1 : currentScreenIndex - 1
                return AdjacentScreens(prev: screens[prevIndex], next: screens[nextIndex])
            }
        }
        return nil
    }

    func order(screens: [NSScreen]) -> [NSScreen] {
        return screens.sorted(by: { screen1, screen2 in
            if screen2.frame.maxY <= screen1.frame.minY { return true }
            if screen1.frame.maxY <= screen2.frame.minY { return false }
            return screen1.frame.minX < screen2.frame.minX
        })
    }

    private func computeAreaOfRect(rect: CGRect) -> CGFloat {
        return rect.size.width * rect.size.height
    }
}

struct UsableScreens {
    let currentScreen: NSScreen
    let adjacentScreens: AdjacentScreens?
    let frameOfCurrentScreen: CGRect
    let numScreens: Int
    let screensOrdered: [NSScreen]

    init(currentScreen: NSScreen, adjacentScreens: AdjacentScreens? = nil, numScreens: Int, screensOrdered: [NSScreen]? = nil) {
        self.currentScreen = currentScreen
        self.adjacentScreens = adjacentScreens
        self.frameOfCurrentScreen = currentScreen.frame
        self.numScreens = numScreens
        self.screensOrdered = screensOrdered ?? [currentScreen]
    }
}

struct AdjacentScreens {
    let prev: NSScreen
    let next: NSScreen
}

extension NSScreen {
    func adjustedVisibleFrame(_ ignoreTodo: Bool = false, _ ignoreStage: Bool = false) -> CGRect {
        return visibleFrame
    }

    static var portraitDisplayConnected: Bool {
        NSScreen.screens.contains(where: { !$0.frame.isLandscape })
    }
}
