import SwiftUI

struct LogsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Logs")
                .font(.title3)
                .fontWeight(.semibold)

            Text("No print logs yet.")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .padding(24)
    }
}
