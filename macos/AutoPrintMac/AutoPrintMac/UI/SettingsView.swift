import SwiftUI

struct SettingsView: View {
    @ObservedObject private var configStore = AppConfigStore.shared

    var body: some View {
        TabView {
            StatusView(config: configStore.config, language: configStore.language)
                .tabItem {
                    Label(text(.status), systemImage: "chart.line.uptrend.xyaxis")
                }

            settingsTab
                .tabItem {
                    Label(text(.settings), systemImage: "gearshape")
                }

            LogsView(language: configStore.language)
                .tabItem {
                    Label(text(.logs), systemImage: "doc.text")
                }

            CapabilityView(language: configStore.language)
                .tabItem {
                    Label(text(.capabilities), systemImage: "checkmark.seal")
                }
        }
        .frame(width: 720, height: 460)
    }

    private var settingsTab: some View {
        Form {
            Picker(text(.language), selection: $configStore.language) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }

            LabeledContent(text(.version)) {
                Text(AppVersion.current)
                    .foregroundStyle(.secondary)
            }

            Toggle(text(.automaticPrinting), isOn: $configStore.config.autoPrintEnabled)

            TextField(text(.printer), text: $configStore.config.printerName)

            Stepper(
                "\(text(.scanInterval)): \(configStore.config.scanIntervalSeconds) \(text(.seconds))",
                value: $configStore.config.scanIntervalSeconds,
                in: 5...3600,
                step: 5
            )

            Stepper(
                "\(text(.stableWait)): \(configStore.config.fileStableSeconds) \(text(.seconds))",
                value: $configStore.config.fileStableSeconds,
                in: 1...600
            )

            Stepper(
                "\(text(.retries)): \(configStore.config.maxRetries)",
                value: $configStore.config.maxRetries,
                in: 0...10
            )
        }
        .formStyle(.grouped)
        .padding(24)
    }

    private func text(_ key: L10nKey) -> String {
        L10n.text(key, language: configStore.language)
    }
}
