import SwiftUI

struct LogsView: View {
    let language: AppLanguage
    @ObservedObject private var logStore = PrintLogStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text(.logs))
                .font(.title3)
                .fontWeight(.semibold)

            if logStore.entries.isEmpty {
                Text(text(.noPrintLogsYet))
                    .foregroundStyle(.secondary)
            } else {
                List(logStore.entries.reversed()) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.message)
                        Text(entry.createdAt.formatted(date: .omitted, time: .standard))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }

            Spacer()
        }
        .padding(24)
    }

    private func text(_ key: L10nKey) -> String {
        L10n.text(key, language: language)
    }
}
