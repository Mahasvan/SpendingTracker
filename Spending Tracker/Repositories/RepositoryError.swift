import Foundation

enum RepositoryError: Error, LocalizedError {
    case notFound(String)
    case invalidInput(String)
    case underlying(Error)

    var errorDescription: String? {
        switch self {
        case .notFound(let what): return "Not found: \(what)"
        case .invalidInput(let msg): return "Invalid input: \(msg)"
        case .underlying(let err): return err.localizedDescription
        }
    }
}
