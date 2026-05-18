import SwiftUI

struct CapabilityView: View {
    let language: AppLanguage

    var body: some View {
        List {
            capabilityRow(text(.printers), message: text(.printerCapabilityMessage))
            capabilityRow(text(.pdfFiles), message: text(.pdfCapabilityMessage))
            capabilityRow(text(.images), message: text(.imagesCapabilityMessage))
            capabilityRow(text(.officeDocuments), message: text(.officeCapabilityMessage))
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

    private func text(_ key: L10nKey) -> String {
        L10n.text(key, language: language)
    }
}
