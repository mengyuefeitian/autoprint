import SwiftUI

@main
struct AutoPrintMacApp: App {
    @NSApplicationDelegateAdaptor(MenuBarController.self) private var menuBarController

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
