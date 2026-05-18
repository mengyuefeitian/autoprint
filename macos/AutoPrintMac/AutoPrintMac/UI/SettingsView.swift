import SwiftUI

struct SettingsView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Auto Print")
                .font(.headline)
            Text("Settings will be added in a later task.")
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(width: 360, alignment: .leading)
    }
}
