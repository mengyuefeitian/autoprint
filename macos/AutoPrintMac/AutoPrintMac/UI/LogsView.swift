import SwiftUI

struct LogsView: View {
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(text(.logs))
                .font(.title3)
                .fontWeight(.semibold)

            Text(text(.noPrintLogsYet))
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
    }

    private func text(_ key: L10nKey) -> String {
        L10n.text(key, language: language)
    }
}
