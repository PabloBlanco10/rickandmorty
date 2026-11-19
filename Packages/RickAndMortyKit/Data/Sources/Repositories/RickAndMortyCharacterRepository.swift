import Domain
import Foundation

public struct RickAndMortyCharacterRepository: CharacterRepository {
    private let baseURL: URL
    private let client: HTTPClient

    /// baseURL is the API root (for production, https://rickandmortyapi.com/api).
    /// The default session has no HTTP cache. Injected sessions are also subject
    /// to the client's per-request cache bypass and no-cache header.
    public init(baseURL: URL, session: URLSession? = nil) {
        self.init(baseURL: baseURL, client: HTTPClient(transport: URLSessionTransport(session: session)))
    }

    init(baseURL: URL, client: HTTPClient) {
        self.baseURL = baseURL
        self.client = client
    }

    /// Until the actor TTL cache is introduced, both policies always use networking
    /// and bypass HTTP caching. No application cache is consulted or populated.
    public func searchCharacters(query: String, page: Int, policy _: FetchPolicy) async throws -> CharacterPage {
        try Task.checkCancellation()
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        do {
            let url = try CharacterEndpoint.search(baseURL: baseURL, query: query, page: page)
            let dto: CharacterPageDTO = try await client.get(from: url)
            let result = try dto.toDomain(requestedPage: page)
            try Task.checkCancellation()
            return result
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            try Task.checkCancellation()
            if let error = error as? HTTPClientError {
                if case let .httpStatus(code, body) = error,
                   code == 404, page == 1, !query.isEmpty, Self.isNoMatchResponse(body)
                {
                    return CharacterPage(characters: [], nextPage: nil)
                }
                throw Self.repositoryError(for: error)
            }
            if error is CharacterMappingError {
                throw CharacterRepositoryError.invalidData
            }
            throw CharacterRepositoryError.unexpected
        }
    }

    private static func isNoMatchResponse(_ body: Foundation.Data) -> Bool {
        do {
            return try JSONDecoder().decode(APIErrorDTO.self, from: body).error == "There is nothing here"
        } catch {
            // An unrecognized error body must retain the HTTP failure semantics.
            return false
        }
    }

    private static func repositoryError(for error: HTTPClientError) -> CharacterRepositoryError {
        switch error {
        case .invalidURL:
            .invalidRequest
        case .invalidResponse, .decoding:
            .invalidData
        case .httpStatus:
            .serviceFailure
        case let .transport(code):
            switch code {
            case .notConnectedToInternet, .networkConnectionLost, .cannotFindHost,
                 .cannotConnectToHost, .dnsLookupFailed, .timedOut, .dataNotAllowed,
                 .internationalRoamingOff:
                .networkUnavailable
            default:
                .serviceFailure
            }
        case .unexpected:
            .unexpected
        }
    }
}
