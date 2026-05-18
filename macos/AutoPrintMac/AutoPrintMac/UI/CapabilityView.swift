import SwiftUI

struct CapabilityView: View {
    var body: some View {
        List {
            capabilityRow("Printers", message: "Uses macOS printer selection and the configured printer name when available.")
            capabilityRow("PDF files", message: "PDF printing is supported through the macOS print adapter.")
            capabilityRow("Images", message: "Common image files can be sent to the macOS print system.")
            capabilityRow("Office documents", message: "Office formats may require an installed app that can print them on this Mac.")
        }
        .listStyle(.inset)
        .padding(12)
    }

    private func capabilityRow(_ title: String, message: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .fontWeight(.semibold)
            Text(message)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
