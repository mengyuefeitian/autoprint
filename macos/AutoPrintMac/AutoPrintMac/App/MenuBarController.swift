import AppKit
import SwiftUI

final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var pauseMenuItem: NSMenuItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Auto Print"

        let menu = NSMenu()
        menu.delegate = self
        let settingsItem = NSMenuItem(title: "Open Settings", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)

        let pauseItem = NSMenuItem(title: "", action: #selector(togglePrinting), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(pauseItem)
        pauseMenuItem = pauseItem
        updatePauseMenuItem()

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem?.menu = menu
    }

    @objc private func openSettings() {
        if let settingsWindow {
            settingsWindow.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 460),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "AutoPrint Settings"
        window.contentViewController = NSHostingController(rootView: SettingsView())
        window.center()
        window.isReleasedWhenClosed = false
        window.delegate = self
        settingsWindow = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func togglePrinting() {
        AppConfigStore.shared.toggleAutoPrintEnabled()
        updatePauseMenuItem()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updatePauseMenuItem() {
        let enabled = AppConfigStore.shared.config.autoPrintEnabled
        pauseMenuItem?.title = enabled ? "Pause Printing" : "Resume Printing"
        pauseMenuItem?.state = enabled ? .off : .on
    }
}

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updatePauseMenuItem()
    }
}

extension MenuBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === settingsWindow {
            settingsWindow = nil
        }
    }
}
