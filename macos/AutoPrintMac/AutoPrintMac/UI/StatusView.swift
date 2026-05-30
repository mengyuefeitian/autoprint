import SwiftUI

struct StatusView: View {
    let config: AppConfig
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                statusIndicator

                VStack(alignment: .leading, spacing: 4) {
                    Text(config.autoPrintEnabled ? text(.running) : text(.paused))
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(config.autoPrintEnabled ? text(.automaticPrintingEnabled) : text(.automaticPrintingPaused))
                        .foregroundStyle(.secondary)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 14) {
                GridRow {
                    Text(text(.printer))
                        .foregroundStyle(.secondary)
                    Text(printerName)
                }

                GridRow {
                    Text(text(.watchFolders))
                        .foregroundStyle(.secondary)
                    Text("\(config.watchFolders.filter(\.enabled).count)")
                }

                GridRow {
                    Text(text(.scanInterval))
                        .foregroundStyle(.secondary)
                    Text("\(config.scanIntervalSeconds) \(text(.seconds))")
                }

                GridRow {
                    Text(text(.scanTimeRange))
                        .foregroundStyle(.secondary)
                    Text(scanTimeRange)
                }

                GridRow {
                    Text(text(.version))
                        .foregroundStyle(.secondary)
                    Text(AppVersion.current)
                }
            }
            .font(.body)

            Spacer()
        }
        .padding(24)
    }

    private var statusIndicator: some View {
        Circle()
            .fill(config.autoPrintEnabled ? Color.green : Color.orange)
            .frame(width: 14, height: 14)
            .accessibilityHidden(true)
    }

    private var printerName: String {
        config.printerName.isEmpty ? text(.defaultPrinter) : config.printerName
    }

    private var scanTimeRange: String {
        guard config.scanSchedule.enabled else {
            return text(.unrestricted)
        }

        return "\(formatMinute(config.scanSchedule.startMinuteOfDay)) - \(formatMinute(config.scanSchedule.endMinuteOfDay))"
    }

    private func formatMinute(_ minute: Int) -> String {
        let clamped = min(max(minute, 0), (24 * 60) - 1)
        return String(format: "%02d:%02d", clamped / 60, clamped % 60)
    }

    private func text(_ key: L10nKey) -> String {
        L10n.text(key, language: language)
    }
}
