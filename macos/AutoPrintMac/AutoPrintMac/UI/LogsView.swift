import AppKit
import SwiftUI

struct LogsView: View {
    let language: AppLanguage
    @ObservedObject private var logStore = PrintLogStore.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(text(.logs))
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Button(text(.copyLogs), action: copyLogs)
                    .disabled(logStore.entries.isEmpty)
            }

            if logStore.entries.isEmpty {
                Text(text(.noPrintLogsYet))
                    .foregroundStyle(.secondary)
            } else {
                TextEditor(text: .constant(formattedLogs))
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(minHeight: 320)
                    .border(Color.secondary.opacity(0.25))
            }

            Spacer()
        }
        .padding(24)
    }

    private func text(_ key: L10nKey) -> String {
        L10n.text(key, language: language)
    }

    private var formattedLogs: String {
        logStore.entries
            .reversed()
            .map { entry in
                let time = entry.createdAt.formatted(date: .omitted, time: .standard)
                return "[\(time)] \(entry.message)"
            }
            .joined(separator: "\n")
    }

    private func copyLogs() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(formattedLogs, forType: .string)
    }
}
