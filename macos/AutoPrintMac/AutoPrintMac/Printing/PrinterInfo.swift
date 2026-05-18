import Foundation

struct PrinterInfo: Identifiable, Equatable {
    var id: String { name }

    let name: String
    let isAvailable: Bool
    let reason: String?
}
