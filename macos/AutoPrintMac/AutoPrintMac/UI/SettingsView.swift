import SwiftUI

struct SettingsView: View {
    @ObservedObject private var configStore = AppConfigStore.shared

    var body: some View {
        TabView {
            StatusView(config: configStore.config)
                .tabItem {
                    Label("Status", systemImage: "chart.line.uptrend.xyaxis")
                }

            settingsTab
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }

            LogsView()
                .tabItem {
                    Label("Logs", systemImage: "doc.text")
                }

            CapabilityView()
                .tabItem {
                    Label("Capabilities", systemImage: "checkmark.seal")
                }
        }
        .frame(width: 720, height: 460)
    }

    private var settingsTab: some View {
        Form {
            Toggle("Automatic printing", isOn: $configStore.config.autoPrintEnabled)

            TextField("Printer", text: $configStore.config.printerName)

            Stepper(
                "Scan interval: \(configStore.config.scanIntervalSeconds) seconds",
                value: $configStore.config.scanIntervalSeconds,
                in: 5...3600,
                step: 5
            )

            Stepper(
                "Stable wait: \(configStore.config.fileStableSeconds) seconds",
                value: $configStore.config.fileStableSeconds,
                in: 1...600
            )

            Stepper(
                "Retries: \(configStore.config.maxRetries)",
                value: $configStore.config.maxRetries,
                in: 0...10
            )
        }
        .formStyle(.grouped)
        .padding(24)
    }
}
