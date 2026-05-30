//
//  MultiWindowManager.swift
//  GridSnap
//
//  Created by Mikhail (Dirondin) Polubisok on 2/20/22.
//  Copyright © 2026 Kurry Tran. All rights reserved.
//

import Cocoa

class AppPickerWindowController: NSObject, NSWindowDelegate {

    struct AppInfo {
        let name: String
        let pid: pid_t
        let icon: NSImage?
    }

    var cascadeButton: String = "Cascade"

    private var panel: NSPanel?
    private var rows: [(checkbox: NSButton, pid: pid_t)] = []
    private var resultPIDs: [pid_t] = []

    func show(apps: [AppInfo]) -> [pid_t] {
        rows = []
        resultPIDs = []
        buildPanel(apps: apps)
        guard let panel = panel else { return [] }
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        NSApp.runModal(for: panel)
        return resultPIDs
    }

    private func buildPanel(apps: [AppInfo]) {
        let rowH: CGFloat = 28
        let hPad: CGFloat = 16
        let buttonH: CGFloat = 44
        let headerH: CGFloat = 36
        let width: CGFloat = 280
        let height = headerH + CGFloat(apps.count) * rowH + buttonH

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "Cascade App Windows"
        panel.isFloatingPanel = true
        panel.level = .modalPanel
        panel.delegate = self
        self.panel = panel

        guard let cv = panel.contentView else { return }

        let label = NSTextField(labelWithString: "Cascade windows for:")
        label.frame = NSRect(x: hPad, y: height - headerH + 8, width: width - hPad * 2, height: 20)
        label.font = .systemFont(ofSize: NSFont.systemFontSize)
        cv.addSubview(label)

        for (i, app) in apps.enumerated() {
            let rowY = buttonH + CGFloat(apps.count - 1 - i) * rowH
            let row = NSStackView(frame: NSRect(x: hPad, y: rowY, width: width - hPad * 2, height: rowH))
            row.orientation = .horizontal
            row.spacing = 6
            row.alignment = .centerY

            if let icon = app.icon {
                let imgView = NSImageView(image: icon)
                imgView.translatesAutoresizingMaskIntoConstraints = false
                imgView.widthAnchor.constraint(equalToConstant: 16).isActive = true
                imgView.heightAnchor.constraint(equalToConstant: 16).isActive = true
                row.addArrangedSubview(imgView)
            }

            let checkbox = NSButton(checkboxWithTitle: app.name, target: nil, action: nil)
            checkbox.state = .on
            row.addArrangedSubview(checkbox)

            cv.addSubview(row)
            rows.append((checkbox: checkbox, pid: app.pid))
        }

        let cancelBtn = NSButton(title: "Cancel", target: self, action: #selector(onCancel))
        cancelBtn.frame = NSRect(x: width - 160, y: 12, width: 68, height: 22)
        cancelBtn.keyEquivalent = "\u{1b}"
        cv.addSubview(cancelBtn)

        let cascadeBtn = NSButton(title: cascadeButton, target: self, action: #selector(onCascade))
        cascadeBtn.frame = NSRect(x: width - 84, y: 10, width: 76, height: 26)
        cascadeBtn.bezelStyle = .rounded
        cascadeBtn.keyEquivalent = "\r"
        cv.addSubview(cascadeBtn)
    }

    @objc private func onCancel() { panel?.close() }

    @objc private func onCascade() {
        resultPIDs = rows.filter { $0.checkbox.state == .on }.map { $0.pid }
        panel?.close()
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.stopModal()
    }
}

class MultiWindowManager {
    private static let cascadeDelta: CGFloat = 30
    private static let tileGap: CGFloat = 2

    private static func allWindowsOnScreen(windowElement: AccessibilityElement? = nil, sortByPID: Bool = false) -> (screens: UsableScreens, windows: [AccessibilityElement])? {
        let screenDetection = ScreenDetection()

        // When called from the menu bar (windowElement == nil), the previously focused app's
        // front window may be on a different screen than the one the user is looking at.
        // Use cursor position instead — the menu bar is always on the screen where the cursor is.
        let screens: UsableScreens?
        if let windowElement = windowElement {
            screens = screenDetection.detectScreens(using: windowElement)
        } else {
            screens = screenDetection.detectScreensAtCursor()
        }
        guard let screens = screens else {
            NSSound.beep()
            return nil
        }

        let currentScreen = screens.currentScreen

        var windows = AccessibilityElement.getAllWindowElements()
        if sortByPID {
            windows.sort(by: { (w1: AccessibilityElement, w2: AccessibilityElement) -> Bool in
                w1.pid ?? pid_t(0) > w2.pid ?? pid_t(0)
            })
        }

        var actualWindows = [AccessibilityElement]()
        for w in windows {
            let frame = w.frame
            guard !frame.isNull else { continue }           // skip if AX position or size is unreadable
            let screen = screenDetection.detectScreens(using: w)?.currentScreen
            if screen == currentScreen,
               w.isWindow == true,
               w.isSheet != true,
               w.isMinimized != true,
               w.isHidden != true,
               w.isSystemDialog != true,
               frame.width >= 100,
               frame.height >= 100
            {
                actualWindows.append(w)
            }
        }

        return (screens, actualWindows)
    }

    static func tileAllWindowsOnScreen(windowElement: AccessibilityElement? = nil) {
        guard let (screens, windows) = allWindowsOnScreen(windowElement: windowElement, sortByPID: true) else {
            return
        }
        applyTileRects(to: windows, visibleFrame: screens.currentScreen.adjustedVisibleFrame())
    }

    static func cascadeAllWindowsOnScreen(windowElement: AccessibilityElement? = nil) {
        guard let (screens, windows) = allWindowsOnScreen(windowElement: windowElement, sortByPID: true) else {
            return
        }

        let screenFrame = screens.currentScreen.adjustedVisibleFrame().screenFlipped

        let delta = cascadeDelta

        for (ind, w) in windows.enumerated() {
            cascadeWindow(w, screenFrame: screenFrame, delta: delta, index: ind)
        }
    }

    private struct CascadeActiveAppParameters {
        let right: Bool
        let bottom: Bool
        let numWindows: Int
        let size: CGSize

        init(windowFrame: CGRect, screenFrame: CGRect, numWindows: Int, size: CGSize, delta: CGFloat) {
            right = windowFrame.midX > screenFrame.midX
            bottom = windowFrame.midY > screenFrame.midY
            self.numWindows = numWindows
            let maxSize = CGSize(width: screenFrame.width - CGFloat(numWindows - 1) * delta, height: screenFrame.height - CGFloat(numWindows - 1) * delta)
            self.size = CGSize(width: min(size.width, maxSize.width), height: min(size.height, maxSize.height))
        }
    }

    static func cascadeActiveAppWindowsOnScreen(windowElement: AccessibilityElement? = nil) {
        guard let (screens, windows) = allWindowsOnScreen(windowElement: windowElement, sortByPID: true),
              let frontWindowElement = AccessibilityElement.getFrontWindowElement()
        else {
            return
        }

        let screenFrame = screens.currentScreen.adjustedVisibleFrame().screenFlipped

        let delta = cascadeDelta

        // keep windows with a pid equal to the front window's pid
        var filtered = windows.filter(hasFrontWindowPid(_:))

        // parameters for cascading active app windows
        var cascadeParameters: CascadeActiveAppParameters?

        if let first = filtered.first {
            // move the first to become the last (top)
            filtered.append(filtered.removeFirst())
            // set up parameters
            cascadeParameters = CascadeActiveAppParameters(windowFrame: first.frame, screenFrame: screenFrame, numWindows: filtered.count, size: first.size!, delta: delta)
        }

        // cascade the filtered windows
        for (ind, w) in filtered.enumerated() {
            cascadeWindow(w, screenFrame: screenFrame, delta: delta, index: ind, cascadeParameters: cascadeParameters)
        }

        // return true for a w pid equal to the front window's pid
        func hasFrontWindowPid(_ w: AccessibilityElement) -> Bool {
            return w.pid == frontWindowElement.pid
        }
    }

    private static func cascadeWindow(_ w: AccessibilityElement, screenFrame: CGRect, delta: CGFloat, index: Int, cascadeParameters: CascadeActiveAppParameters? = nil) {
        var rect = w.frame

        // TODO: save previous position in history

        rect.origin.x = screenFrame.origin.x + delta * CGFloat(index)
        rect.origin.y = screenFrame.origin.y + delta * CGFloat(index)

        if let cascadeParameters {
            rect.size.width = cascadeParameters.size.width
            rect.size.height = cascadeParameters.size.height

            if cascadeParameters.right {
                rect.origin.x = screenFrame.origin.x + screenFrame.size.width - cascadeParameters.size.width - delta * CGFloat(index)
            }
            if cascadeParameters.bottom {
                rect.origin.y = screenFrame.origin.y + screenFrame.size.height - cascadeParameters.size.height - delta * CGFloat(cascadeParameters.numWindows - 1 - index)
            }
        }

        w.setFrame(rect)
        w.bringToFront()
    }

    /// Finds the column count that best fills the screen with the given number of windows.
    /// Minimizes blank cells; breaks ties by preferring tiles whose aspect ratio matches
    /// `targetAspect` (width / height). Default 1 keeps tiles square; pass the windows'
    /// natural aspect ratio (e.g. ~1.6 for terminals) to avoid distorting their shape.
    static func bestLayout(count: Int, screenWidth: CGFloat, screenHeight: CGFloat, targetAspect: CGFloat = 1) -> (columns: Int, rows: Int) {
        guard count > 1 else { return (1, 1) }
        // Guard against a degenerate target (zero/negative/non-finite) collapsing the score.
        let target = (targetAspect.isFinite && targetAspect > 0) ? targetAspect : 1
        let sqrtN = sqrt(CGFloat(count))
        // Bound search to avoid single-row or single-column extremes
        let minCols = max(1, Int(ceil(sqrtN / 2)))
        let maxCols = min(count, Int(ceil(sqrtN * 2)))
        var bestCols = max(1, Int(sqrtN.rounded()))
        var bestScore = CGFloat.infinity
        for cols in minCols...maxCols {
            let rows = Int(ceil(CGFloat(count) / CGFloat(cols)))
            let blanks = CGFloat(cols * rows - count)
            let tileAspect = (screenWidth / CGFloat(cols)) / (screenHeight / CGFloat(rows))
            // Penalize blank cells heavily; then prefer tiles whose aspect ratio is closest
            // to the windows' natural ratio. log() makes the penalty symmetric: a tile twice
            // as wide as the target is penalized the same as one twice as tall.
            let score = blanks * 1.5 + abs(log(tileAspect / target))
            if score < bestScore {
                bestScore = score
                bestCols = cols
            }
        }
        return (bestCols, Int(ceil(CGFloat(count) / CGFloat(bestCols))))
    }

    /// Median width/height aspect ratio of a set of window frames, clamped to a sane range
    /// so one freakishly tall or wide window can't force a single-row/single-column grid.
    /// Returns 1 (square) when there is nothing usable to measure.
    static func medianAspect(of frames: [CGRect]) -> CGFloat {
        let aspects = frames
            .filter { !$0.isNull && $0.width > 0 && $0.height > 0 }
            .map { $0.width / $0.height }
            .sorted()
        guard !aspects.isEmpty else { return 1 }
        let median = aspects[aspects.count / 2]
        return min(max(median, 0.33), 3.0)
    }

    /// Pure spatial ordering for unit testing.
    /// Takes window frames in AX coordinates (Y=0 at top of main screen, Y increases downward)
    /// and returns the input indices sorted top-to-bottom, left-to-right with row grouping.
    /// Frames are read exactly once — no repeated AX calls, deterministic.
    static func spatialOrder(frames: [CGRect]) -> [Int] {
        guard frames.count > 1 else { return Array(frames.indices) }

        // Sort indices by midY ascending (smaller Y = closer to top in AX coords)
        let byY = frames.indices.sorted { frames[$0].midY < frames[$1].midY }

        // Row-grouping threshold: half of median window height
        let sortedHeights = frames.map { $0.height }.sorted()
        let medianH = sortedHeights[sortedHeights.count / 2]
        let threshold = medianH * 0.5

        var rows: [[Int]] = []
        for idx in byY {
            if let anchorY = rows.last?.first.map({ frames[$0].midY }),
               frames[idx].midY - anchorY <= threshold {
                rows[rows.count - 1].append(idx)
            } else {
                rows.append([idx])
            }
        }

        return rows.flatMap { $0.sorted { frames[$0].midX < frames[$1].midX } }
    }

    /// Sorts windows spatially: top-to-bottom, left-to-right.
    /// Snapshots all AX frames once before sorting to avoid repeated API calls.
    /// Windows with unreadable frames are placed at the end rather than dropped,
    /// so they still occupy a grid slot and the total count stays correct.
    static func sortedSpatially(_ windows: [AccessibilityElement]) -> [AccessibilityElement] {
        guard windows.count > 1 else { return windows }
        let frames = windows.map { $0.frame }
        var validIdx = [Int](), nullIdx = [Int]()
        for i in frames.indices {
            if frames[i].isNull { nullIdx.append(i) } else { validIdx.append(i) }
        }
        guard validIdx.count > 1 else { return windows }
        let order = spatialOrder(frames: validIdx.map { frames[$0] })
        return order.map { windows[validIdx[$0]] } + nullIdx.map { windows[$0] }
    }

    /// Pure layout math: returns one CGRect per window in normal macOS coordinates (origin bottom-left).
    /// Callers must convert each rect with .screenFlipped before passing to setFrame.
    static func tileRects(count: Int, in visibleFrame: CGRect, gap: CGFloat, targetAspect: CGFloat = 1) -> [CGRect] {
        guard count > 0 else { return [] }
        let (columns, rows) = bestLayout(count: count, screenWidth: visibleFrame.width, screenHeight: visibleFrame.height, targetAspect: targetAspect)
        // Gap is only between tiles, not at the outer edges.
        let tileW = floor((visibleFrame.width  - gap * CGFloat(columns - 1)) / CGFloat(columns))
        let tileH = floor((visibleFrame.height - gap * CGFloat(rows - 1))    / CGFloat(rows))
        return (0..<count).map { ind in
            let col = ind % columns
            let row = ind / columns
            var rect = CGRect.zero
            rect.size = CGSize(width: tileW, height: tileH)
            rect.origin.x = visibleFrame.minX + (tileW + gap) * CGFloat(col)
            rect.origin.y = visibleFrame.maxY - (tileH + gap) * CGFloat(row) - tileH
            return rect
        }
    }

    private static func applyTileRects(to windows: [AccessibilityElement], visibleFrame: CGRect) {
        let ordered = sortedSpatially(windows)
        // Choose the grid that best preserves the windows' natural shape (e.g. ~1.6:1
        // terminals stay landscape) instead of forcing every tile toward a square.
        let targetAspect = medianAspect(of: ordered.map { $0.frame })
        let rects = tileRects(count: ordered.count, in: visibleFrame, gap: tileGap, targetAspect: targetAspect)
        var seenPIDs = Set<pid_t>()
        for (w, rect) in zip(ordered, rects) {
            w.setFrame(rect.screenFlipped)
            w.raise()
            if let pid = w.pid { seenPIDs.insert(pid) }
        }
        for pid in seenPIDs {
            NSRunningApplication(processIdentifier: pid)?.activate(options: .activateIgnoringOtherApps)
        }
    }

    // Called from the menu submenu — tile all windows belonging to a specific PID in a perfect grid
    static func tileWindowsForPID(_ targetPID: pid_t, windowElement: AccessibilityElement? = nil) {
        guard let (screens, windows) = allWindowsOnScreen(windowElement: windowElement, sortByPID: true) else { return }
        let filtered = windows.filter { $0.pid == targetPID }
        guard !filtered.isEmpty else { return }
        applyTileRects(to: filtered, visibleFrame: screens.currentScreen.adjustedVisibleFrame())
    }

    // Called from the menu submenu — cascade all windows belonging to a specific PID
    static func cascadeWindowsForPID(_ targetPID: pid_t, windowElement: AccessibilityElement? = nil) {
        guard let (screens, windows) = allWindowsOnScreen(windowElement: windowElement, sortByPID: true) else { return }
        let screenFrame = screens.currentScreen.adjustedVisibleFrame().screenFlipped
        let filtered = windows.filter { $0.pid == targetPID }
        guard !filtered.isEmpty else { return }
        let delta = cascadeDelta
        for (ind, w) in filtered.enumerated() {
            cascadeWindow(w, screenFrame: screenFrame, delta: delta, index: ind)
        }
    }

    // Called from keyboard shortcut — falls back to modal picker
    static func tileSpecificAppsWindowsOnScreen(windowElement: AccessibilityElement? = nil) {
        guard let (screens, windows) = allWindowsOnScreen(windowElement: windowElement, sortByPID: true) else { return }

        var seen = Set<pid_t>()
        var apps: [AppPickerWindowController.AppInfo] = []
        for w in windows {
            guard let pid = w.pid, !seen.contains(pid) else { continue }
            seen.insert(pid)
            let runningApp = NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
            apps.append(AppPickerWindowController.AppInfo(name: runningApp?.localizedName ?? "Unknown", pid: pid, icon: runningApp?.icon))
        }
        guard !apps.isEmpty else { return }

        let picker = AppPickerWindowController()
        picker.cascadeButton = "Tile"
        let selectedPIDs = Set(picker.show(apps: apps))
        guard !selectedPIDs.isEmpty else { return }

        let filtered = windows.filter { selectedPIDs.contains($0.pid ?? 0) }
        applyTileRects(to: filtered, visibleFrame: screens.currentScreen.adjustedVisibleFrame())
    }

    // Called from keyboard shortcut — falls back to modal picker
    static func cascadeSpecificAppsWindowsOnScreen(windowElement: AccessibilityElement? = nil) {
        guard let (screens, windows) = allWindowsOnScreen(windowElement: windowElement, sortByPID: true) else { return }
        let screenFrame = screens.currentScreen.adjustedVisibleFrame().screenFlipped

        var seen = Set<pid_t>()
        var apps: [AppPickerWindowController.AppInfo] = []
        for w in windows {
            guard let pid = w.pid, !seen.contains(pid) else { continue }
            seen.insert(pid)
            let runningApp = NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
            apps.append(AppPickerWindowController.AppInfo(name: runningApp?.localizedName ?? "Unknown", pid: pid, icon: runningApp?.icon))
        }
        guard !apps.isEmpty else { return }

        let picker = AppPickerWindowController()
        let selectedPIDs = Set(picker.show(apps: apps))
        guard !selectedPIDs.isEmpty else { return }

        let filtered = windows.filter { selectedPIDs.contains($0.pid ?? 0) }
        let delta = cascadeDelta
        for (ind, w) in filtered.enumerated() {
            cascadeWindow(w, screenFrame: screenFrame, delta: delta, index: ind)
        }
    }

    static func tileActiveAppWindowsOnScreen(windowElement: AccessibilityElement? = nil) {
        guard let (screens, windows) = allWindowsOnScreen(windowElement: windowElement, sortByPID: true),
              let frontWindowElement = AccessibilityElement.getFrontWindowElement()
        else { return }
        let filtered = windows.filter { $0.pid == frontWindowElement.pid }
        guard !filtered.isEmpty else { return }
        applyTileRects(to: filtered, visibleFrame: screens.currentScreen.adjustedVisibleFrame())
    }
}
