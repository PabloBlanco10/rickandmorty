import Domain

/// Only connectivity has distinct recovery guidance; other failures offer retry.
enum CharactersError: Error, Equatable {
    case connection, service

    var message: String {
        switch self {
        case .connection: "Check your internet connection and try again."
        case .service: "Characters could not be loaded. Please try again."
        }
    }

    init(_ error: any Error) {
        if let error = error as? CharactersError {
            self = error
            return
        }
        self = (error as? CharacterRepositoryError) == .networkUnavailable ? .connection : .service
    }
}
