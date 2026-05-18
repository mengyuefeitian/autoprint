import AppKit

final class MenuBarController: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var pauseMenuItem: NSMenuItem?

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
        NSApp.activate(ignoringOtherApps: true)
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
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
