import AppKit
import SwiftUI

final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var settingsMenuItem: NSMenuItem?
    private var logsMenuItem: NSMenuItem?
    private var pauseMenuItem: NSMenuItem?
    private var quitMenuItem: NSMenuItem?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        configureStatusItemIcon()
        AutoPrintEngine.shared.start()

        let menu = NSMenu()
        menu.delegate = self
        let settingsItem = NSMenuItem(title: "", action: #selector(openSettings), keyEquivalent: ",")
        settingsItem.target = self
        menu.addItem(settingsItem)
        settingsMenuItem = settingsItem

        let logsItem = NSMenuItem(title: "", action: #selector(openLogDirectory), keyEquivalent: "l")
        logsItem.target = self
        menu.addItem(logsItem)
        logsMenuItem = logsItem

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

    @objc private func openLogDirectory() {
        let directory = PrintLogStore.shared.logDirectory
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        NSWorkspace.shared.open(directory)
    }

    @objc private func quit() {
        AutoPrintEngine.shared.stop()
        NSApp.terminate(nil)
    }

    private func updateMenuTitles() {
        let language = AppConfigStore.shared.language
        let enabled = AppConfigStore.shared.config.autoPrintEnabled
        settingsMenuItem?.title = text(.openSettings, language: language)
        logsMenuItem?.title = text(.openLogDirectory, language: language)
        pauseMenuItem?.title = enabled ? text(.pausePrinting, language: language) : text(.resumePrinting, language: language)
        pauseMenuItem?.state = enabled ? .off : .on
        quitMenuItem?.title = text(.quit, language: language)
    }

    private func text(_ key: L10nKey, language: AppLanguage) -> String {
        L10n.text(key, language: language)
    }

    private func configureStatusItemIcon() {
        statusItem?.button?.title = ""
        statusItem?.button?.toolTip = "AutoPrint"

        guard let iconURL = Bundle.main.url(forResource: "AutoPrint", withExtension: "icns"),
              let image = NSImage(contentsOf: iconURL) else {
            statusItem?.button?.title = "AP"
            return
        }

        image.size = NSSize(width: 18, height: 18)
        statusItem?.button?.image = image
        statusItem?.button?.imagePosition = .imageOnly
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
