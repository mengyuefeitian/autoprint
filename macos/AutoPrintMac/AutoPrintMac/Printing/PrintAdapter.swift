import Foundation

protocol PrintAdapter {
    func print(file: URL, printerName: String, timeoutSeconds: Int) async throws
}

enum PrintAdapterError: Error, LocalizedError {
    case unsupportedType(String)
    case commandFailed(String)
    case timedOut

    var errorDescription: String? {
        switch self {
        case .unsupportedType(let fileExtension):
            return "Unsupported file type: \(fileExtension)"
        case .commandFailed(let message):
            return message
        case .timedOut:
            return "Print command timed out"
        }
    }
}
