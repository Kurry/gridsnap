import Cocoa

@NSApplicationMain
class AppDelegate: NSObject, NSApplicationDelegate {

    private let accessibilityAuthorization = AccessibilityAuthorization()
    private var statusItem: NSStatusItem!
    private var cascadeAppsSubmenu: NSMenu?
    private var tileAppsSubmenu: NSMenu?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let trusted = accessibilityAuthorization.checkAccessibility {
            self.setUp()
        }
        if trusted { setUp() }
    }

    private func setUp() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            if #available(macOS 11.0, *) {
                button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: "Cascade")
            } else {
                button.image = NSImage(named: NSImage.applicationIconName)
            }
        }
        buildMenu()
    }

    private func buildMenu() {
        let menu = NSMenu()
        menu.delegate = self

        let cascadeItem = NSMenuItem(title: "Cascade", action: nil, keyEquivalent: "")
        let cascadeMenu = NSMenu(title: "Cascade")
        cascadeMenu.delegate = self
        cascadeMenu.autoenablesItems = false
        cascadeAppsSubmenu = cascadeMenu
        cascadeItem.submenu = cascadeMenu
        menu.addItem(cascadeItem)

        let tileItem = NSMenuItem(title: "Tile", action: nil, keyEquivalent: "")
        let tileMenu = NSMenu(title: "Tile")
        tileMenu.delegate = self
        tileMenu.autoenablesItems = false
        tileAppsSubmenu = tileMenu
        tileItem.submenu = tileMenu
        menu.addItem(tileItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    private func populateAppSubmenu(_ menu: NSMenu, action: Selector) {
        menu.removeAllItems()
        let windows = AccessibilityElement.getAllWindowElements()
        var seen = Set<pid_t>()
        var apps: [(name: String, pid: pid_t, icon: NSImage?)] = []
        for w in windows {
            guard let pid = w.pid, !seen.contains(pid) else { continue }
            seen.insert(pid)
            let app = NSWorkspace.shared.runningApplications.first { $0.processIdentifier == pid }
            apps.append((name: app?.localizedName ?? "Unknown", pid: pid, icon: app?.icon))
        }
        apps.sort { $0.name < $1.name }
        for info in apps {
            let item = NSMenuItem(title: info.name, action: action, keyEquivalent: "")
            item.target = self
            item.representedObject = NSNumber(value: info.pid)
            item.isEnabled = true
            if let icon = info.icon {
                let img = icon.copy() as! NSImage
                img.size = NSSize(width: 16, height: 16)
                item.image = img
            }
            menu.addItem(item)
        }
        if apps.isEmpty {
            let empty = NSMenuItem(title: "No windows on screen", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        }
    }

    @objc private func cascadeApp(sender: NSMenuItem) {
        guard let pid = sender.representedObject as? NSNumber else { return }
        MultiWindowManager.cascadeWindowsForPID(pid_t(pid.int32Value))
    }

    @objc private func tileApp(sender: NSMenuItem) {
        guard let pid = sender.representedObject as? NSNumber else { return }
        MultiWindowManager.tileWindowsForPID(pid_t(pid.int32Value))
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        if menu == cascadeAppsSubmenu {
            populateAppSubmenu(menu, action: #selector(cascadeApp))
        } else if menu == tileAppsSubmenu {
            populateAppSubmenu(menu, action: #selector(tileApp))
        }
    }
}
