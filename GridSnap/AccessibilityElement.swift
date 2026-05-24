//
//  AccessibilityElement.swift
//  GridSnap
//
//  Created by Kurry Tran on 6/12/19.
//  Copyright © 2026 Kurry Tran. All rights reserved.
//

import Foundation

class AccessibilityElement {
    fileprivate let wrappedElement: AXUIElement

    init(_ element: AXUIElement) {
        wrappedElement = element
    }

    convenience init(_ pid: pid_t) {
        self.init(AXUIElementCreateApplication(pid))
    }

    convenience init?(_ bundleIdentifier: String) {
        guard let app = (NSWorkspace.shared.runningApplications.first { $0.bundleIdentifier == bundleIdentifier }) else { return nil }
        self.init(app.processIdentifier)
    }

    convenience init?(_ position: CGPoint) {
        guard let element = AXUIElement.systemWide.getElementAtPosition(position) else { return nil }
        self.init(element)
    }

    private func getElementValue(_ attribute: NSAccessibility.Attribute) -> AccessibilityElement? {
        guard let value = wrappedElement.getValue(attribute), CFGetTypeID(value) == AXUIElementGetTypeID() else { return nil }
        return AccessibilityElement(value as! AXUIElement)
    }

    private func getElementsValue(_ attribute: NSAccessibility.Attribute) -> [AccessibilityElement]? {
        guard let value = wrappedElement.getValue(attribute), let array = value as? [AXUIElement] else { return nil }
        return array.map { AccessibilityElement($0) }
    }

    private var role: NSAccessibility.Role? {
        guard let value = wrappedElement.getValue(.role) as? String else { return nil }
        return NSAccessibility.Role(rawValue: value)
    }

    private var isApplication: Bool? {
        guard let role = role else { return nil }
        return role == .application
    }

    var isWindow: Bool? {
        guard let role = role else { return nil }
        return role == .window
    }

    var isSheet: Bool? {
        guard let role = role else { return nil }
        return role == .sheet
    }

    var isToolbar: Bool? {
        guard let role = role else { return nil }
        return role == .toolbar
    }

    var isGroup: Bool? {
        guard let role = role else { return nil }
        return role == .group
    }

    var isTabGroup: Bool? {
        guard let role = role else { return nil }
        return role == .tabGroup
    }

    var isStaticText: Bool? {
        guard let role = role else { return nil }
        return role == .staticText
    }

    private var subrole: NSAccessibility.Subrole? {
        guard let value = wrappedElement.getValue(.subrole) as? String else { return nil }
        return NSAccessibility.Subrole(rawValue: value)
    }

    var isSystemDialog: Bool? {
        guard let subrole = subrole else { return nil }
        return subrole == .systemDialog
    }

    private var position: CGPoint? {
        get {
            wrappedElement.getWrappedValue(.position)
        }
        set {
            guard let newValue = newValue else { return }
            wrappedElement.setValue(.position, newValue)
        }
    }

    func isResizable() -> Bool {
        return wrappedElement.isValueSettable(.size) ?? true
    }

    var size: CGSize? {
        get {
            wrappedElement.getWrappedValue(.size)
        }
        set {
            guard let newValue = newValue else { return }
            wrappedElement.setValue(.size, newValue)
        }
    }

    var frame: CGRect {
        guard let position = position, let size = size else { return .null }
        return .init(origin: position, size: size)
    }

    func setFrame(_ frame: CGRect, adjustSizeFirst: Bool = true) {
        let appElement = applicationElement
        if let appElement = appElement, appElement.enhancedUserInterface == true {
            appElement.enhancedUserInterface = false
        }
        if adjustSizeFirst {
            size = frame.size
        }
        position = frame.origin
        size = frame.size
    }

    private var childElements: [AccessibilityElement]? {
        getElementsValue(.children)
    }

    func getChildElement(_ role: NSAccessibility.Role) -> AccessibilityElement? {
        return childElements?.first { $0.role == role }
    }

    func getChildElements(_ role: NSAccessibility.Role) -> [AccessibilityElement]? {
        guard let elements = (childElements?.filter { $0.role == role }), elements.count > 0 else {
            return nil
        }
        return elements
    }

    func getChildElement(_ subrole: NSAccessibility.Subrole) -> AccessibilityElement? {
        return childElements?.first { $0.subrole == subrole }
    }

    func getChildElements(_ subrole: NSAccessibility.Subrole) -> [AccessibilityElement]? {
        guard let elements = (childElements?.filter { $0.subrole == subrole }), elements.count > 0 else {
            return nil
        }
        return elements
    }

    func getSelfOrChildElementRecursively(_ position: CGPoint) -> AccessibilityElement? {
        func getChildElement() -> AccessibilityElement? {
            return element.childElements?
                .map { (element: $0, frame: $0.frame) }
                .filter { $0.frame.contains(position) }
                .min { $0.frame.width * $0.frame.height < $1.frame.width * $1.frame.height }?
                .element
        }
        var element = self
        var elements = Set<AccessibilityElement>()
        while let childElement = getChildElement(), elements.insert(childElement).inserted {
            element = childElement
        }
        return element
    }

    var windowId: CGWindowID? {
        wrappedElement.getWindowId()
    }

    func getWindowId() -> CGWindowID? {
        if let windowId = windowId {
            return windowId
        }
        let frame = frame
        if let pid = pid, let info = (WindowUtil.getWindowList().first { $0.pid == pid && $0.frame == frame }) {
            return info.id
        }
        return nil
    }

    var pid: pid_t? {
        wrappedElement.getPid()
    }

    var windowElement: AccessibilityElement? {
        if isWindow == true { return self }
        return getElementValue(.window)
    }

    private var isMainWindow: Bool? {
        get {
            windowElement?.wrappedElement.getValue(.main) as? Bool
        }
        set {
            guard let newValue = newValue else { return }
            windowElement?.wrappedElement.setValue(.main, newValue)
        }
    }

    var isMinimized: Bool? {
        windowElement?.wrappedElement.getValue(.minimized) as? Bool
    }

    var isFullScreen: Bool? {
        guard let subrole = windowElement?.getElementValue(.fullScreenButton)?.subrole else { return nil }
        return subrole == .zoomButton
    }

    var titleBarFrame: CGRect? {
        guard
            let windowElement,
            case let windowFrame = windowElement.frame,
            windowFrame != .null,
            let closeButtonFrame = windowElement.getChildElement(.closeButton)?.frame,
            closeButtonFrame != .null
        else {
            return nil
        }
        let gap = closeButtonFrame.minY - windowFrame.minY
        let height = 2 * gap + closeButtonFrame.height
        return CGRect(origin: windowFrame.origin, size: CGSize(width: windowFrame.width, height: height))
    }

    private var applicationElement: AccessibilityElement? {
        if isApplication == true { return self }
        guard let pid = pid else { return nil }
        return AccessibilityElement(pid)
    }

    private var focusedWindowElement: AccessibilityElement? {
        applicationElement?.getElementValue(.focusedWindow)
    }

    var windowElements: [AccessibilityElement]? {
        applicationElement?.getElementsValue(.windows)
    }

    var isHidden: Bool? {
        applicationElement?.wrappedElement.getValue(.hidden) as? Bool
    }

    var enhancedUserInterface: Bool? {
        get {
            applicationElement?.wrappedElement.getValue(.enhancedUserInterface) as? Bool
        }
        set {
            guard let newValue = newValue else { return }
            applicationElement?.wrappedElement.setValue(.enhancedUserInterface, newValue)
        }
    }

    var windowIds: [CGWindowID]? {
        wrappedElement.getValue(.windowIds) as? [CGWindowID]
    }

    func raise() {
        AXUIElementPerformAction(wrappedElement, kAXRaiseAction as CFString)
    }

    func bringToFront(force: Bool = false) {
        if isMainWindow != true {
            isMainWindow = true
        }
        if let pid = pid, let app = NSRunningApplication(processIdentifier: pid), !app.isActive || force {
            app.activate(options: .activateIgnoringOtherApps)
        }
    }
}

extension AccessibilityElement {
    static func getFrontApplicationElement() -> AccessibilityElement? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }
        return AccessibilityElement(app.processIdentifier)
    }

    static func getFrontWindowElement() -> AccessibilityElement? {
        guard let appElement = getFrontApplicationElement() else { return nil }
        if let focusedWindowElement = appElement.focusedWindowElement {
            return focusedWindowElement
        }
        return appElement.windowElements?.first
    }

    static func getWindowElement(_ windowId: CGWindowID) -> AccessibilityElement? {
        guard let pid = WindowUtil.getWindowList(ids: [windowId]).first?.pid else { return nil }
        return AccessibilityElement(pid).windowElements?.first { $0.windowId == windowId }
    }

    private static let excludedProcessNames: Set<String> = ["Dock", "WindowManager", "Notification Center"]

    static func getAllWindowElements() -> [AccessibilityElement] {
        return WindowUtil.getWindowList()
            .filter { !excludedProcessNames.contains($0.processName ?? "") }
            .uniqueMap { $0.pid }
            .compactMap { AccessibilityElement($0).windowElements }
            .flatMap { $0 }
    }
}

extension AccessibilityElement: Equatable {
    static func == (lhs: AccessibilityElement, rhs: AccessibilityElement) -> Bool {
        return lhs.wrappedElement == rhs.wrappedElement
    }
}

extension AccessibilityElement: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(wrappedElement)
    }
}
