import AppKit
import SwiftUI

final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsMenuItem: NSMenuItem?
    private var pauseMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.title = "Auto Print"
        AutoPrintEngine.shared.start()

        let menu = NSMenu()
        menu.delegate = self
        let settingsItem = NSMenuItem(title: "", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        settingsMenuItem = settingsItem

        let pauseItem = NSMenuItem(title: "", action: #selector(togglePrinting), keyEquivalent: "p")
        pauseItem.target = self
        menu.addItem(pauseItem)
        pauseMenuItem = pauseItem
        updateMenuTitles()

        menu.addItem(NSMenuItem.separator())

        let quitItem = NSMenuItem(title: "", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        quitMenuItem = quitItem
        updateMenuTitles()

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
        updateMenuTitles()
    }

    @objc private func quit() {
        AutoPrintEngine.shared.stop()
        NSApp.terminate(nil)
    }

    private func updateMenuTitles() {
        let language = AppConfigStore.shared.language
        let enabled = AppConfigStore.shared.config.autoPrintEnabled
        settingsMenuItem?.title = text(.openSettings, language: language)
        pauseMenuItem?.title = enabled ? text(.pausePrinting, language: language) : text(.resumePrinting, language: language)
        pauseMenuItem?.state = enabled ? .off : .on
        quitMenuItem?.title = text(.quit, language: language)
    }

    private func text(_ key: L10nKey, language: AppLanguage) -> String {
        L10n.text(key, language: language)
    }
}

extension MenuBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        updateMenuTitles()
    }
}

extension MenuBarController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if notification.object as? NSWindow === settingsWindow {
            settingsWindow = nil
        }
    }
}
