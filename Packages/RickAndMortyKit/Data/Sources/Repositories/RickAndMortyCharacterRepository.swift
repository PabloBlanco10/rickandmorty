import Domain
import Foundation

public struct RickAndMortyCharacterRepository: CharacterRepository {
    private let baseURL: URL
    private let client: HTTPClient
    private let cache: MemoryCache<SearchCacheKey, CharacterPage>

    /// baseURL is the API root (for production, https://rickandmortyapi.com/api).
    /// The default session has no HTTP cache. Injected sessions are also subject
    /// to the client's per-request cache bypass and no-cache header.
    public init(baseURL: URL, session: URLSession? = nil, cacheTTL: Duration = .seconds(180)) {
        self.init(
            baseURL: baseURL,
            client: HTTPClient(transport: URLSessionTransport(session: session)),
            cache: MemoryCache(ttl: cacheTTL)
        )
    }

    init(
        baseURL: URL,
        client: HTTPClient,
        cache: MemoryCache<SearchCacheKey, CharacterPage> = MemoryCache()
    ) {
        self.baseURL = baseURL
        self.client = client
        self.cache = cache
    }

    /// Reads valid domain pages or requests a replacement. A superseded response can
    /// still be returned to its caller, but cannot replace newer cached data.
    public func searchCharacters(query: String, page: Int, policy: FetchPolicy) async throws -> CharacterPage {
        try Task.checkCancellation()
        let key = SearchCacheKey(query: query, page: page)
        let url: URL
        do {
            // Validate input even on cache hits, before registering any pending write.
            url = try CharacterEndpoint.search(baseURL: baseURL, query: key.query, page: page)
        } catch let error as HTTPClientError {
            throw Self.repositoryError(for: error)
        }

        if policy == .cacheFirst, let cached = await cache.value(for: key) {
            try Task.checkCancellation()
            return cached
        }

        let token = try await cache.beginWrite(for: key)
        do {
            let result = try await fetchPage(from: url, query: key.query, page: page)
            _ = try await cache.commit(result, using: token)
            try Task.checkCancellation()
            return result
        } catch {
            await cache.finishWrite(token)
            throw error
        }
    }

    private func fetchPage(from url: URL, query: String, page: Int) async throws -> CharacterPage {
        do {
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
