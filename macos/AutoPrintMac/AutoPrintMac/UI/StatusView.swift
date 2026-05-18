import SwiftUI

struct StatusView: View {
    let config: AppConfig

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                statusIndicator

                VStack(alignment: .leading, spacing: 4) {
                    Text(config.autoPrintEnabled ? "Running" : "Paused")
                        .font(.title2)
                        .fontWeight(.semibold)
                    Text(config.autoPrintEnabled ? "Automatic printing is enabled." : "Automatic printing is paused.")
                        .foregroundStyle(.secondary)
                }
            }

            Grid(alignment: .leading, horizontalSpacing: 28, verticalSpacing: 14) {
                GridRow {
                    Text("Printer")
                        .foregroundStyle(.secondary)
                    Text(printerName)
                }

                GridRow {
                    Text("Watch folders")
                        .foregroundStyle(.secondary)
                    Text("\(config.watchFolders.filter(\.enabled).count)")
                }

                GridRow {
                    Text("Scan interval")
                        .foregroundStyle(.secondary)
                    Text("\(config.scanIntervalSeconds) seconds")
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
        config.printerName.isEmpty ? "Default printer" : config.printerName
    }
}
