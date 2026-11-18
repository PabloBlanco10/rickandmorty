/// Failures callers can handle without depending on networking infrastructure.
public enum CharacterRepositoryError: Error, Equatable, Sendable {
    /// A page below one or an invalid API base URL.
    case invalidRequest
    /// A connection could not be established, was lost, or timed out.
    case networkUnavailable
    /// The service rejected the request, including unrecognized 404 responses.
    case serviceFailure
    /// The response cannot be decoded or mapped into valid character data.
    case invalidData
    /// A transport failure outside the recognized URLSession error categories.
    case unexpected
}
