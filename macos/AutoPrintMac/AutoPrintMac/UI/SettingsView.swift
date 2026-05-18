import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject private var configStore = AppConfigStore.shared
    @State private var printers: [PrinterInfo] = PrinterDetector().printers()

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

            Section(text(.printer)) {
                if printers.isEmpty {
                    Text(text(.noPrintersFound))
                        .foregroundStyle(.secondary)
                } else {
                    Picker(text(.selectedPrinter), selection: $configStore.config.printerName) {
                        Text(text(.selectedPrinter)).tag("")
                        ForEach(printers) { printer in
                            Text(printer.name).tag(printer.name)
                        }
                    }
                }

                Button(text(.refresh)) {
                    printers = PrinterDetector().printers()
                }
            }

            Section(text(.watchFolders)) {
                if configStore.config.watchFolders.isEmpty {
                    Text(text(.noWatchFolders))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(configStore.config.watchFolders) { folder in
                        HStack {
                            Toggle(
                                folder.path,
                                isOn: Binding(
                                    get: { folder.enabled },
                                    set: { configStore.setWatchFolder(path: folder.path, enabled: $0) }
                                )
                            )
                            Spacer()
                            Button(text(.remove)) {
                                configStore.removeWatchFolder(path: folder.path)
                            }
                        }
                    }
                }

                Button(text(.addWatchFolder)) {
                    addWatchFolder()
                }
            }

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

    private func addWatchFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = text(.addWatchFolder)

        if panel.runModal() == .OK, let url = panel.url {
            configStore.addWatchFolder(path: url.path)
        }
    }
}
