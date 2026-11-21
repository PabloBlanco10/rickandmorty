@testable import Data
import Domain
import Foundation
import Testing

private enum TestError: Error {
    case unexpected
}

struct RickAndMortyCharacterRepositoryTests {
    @Test
    func validCachedResultsAvoidNetworking() async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.pageData(),
            response: APIResponseFixture.response()
        )
        let repository = try makeRepository(transport: transport)

        let first = try await repository.searchCharacters(query: "Rick", page: 1)
        let second = try await repository.searchCharacters(query: "Rick", page: 1)

        #expect(first == second)
        #expect(first.characters.first?.name == "Rick Sanchez")
        #expect(first.nextPage == 2)
        let requests = await transport.requests
        #expect(requests.count == 1)
        #expect(requests.allSatisfy { $0.cachePolicy == .reloadIgnoringLocalCacheData })
        #expect(requests.allSatisfy { $0.value(forHTTPHeaderField: "Cache-Control") == "no-cache" })
    }

    @Test(arguments: ["", "  \n "])
    func emptyQueryRequestsGeneralList(query: String) async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.pageData(next: nil),
            response: APIResponseFixture.response()
        )
        let repository = try makeRepository(transport: transport)

        _ = try await repository.searchCharacters(query: query, page: 3)

        let requests = await transport.requests
        let url = try #require(requests.first?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == "/api/character")
        #expect(components.queryItems == [URLQueryItem(name: "page", value: "3")])
    }

    @Test
    func encodesSpecialCharactersAndTrimsSearchWhitespace() async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.pageData(next: nil),
            response: APIResponseFixture.response()
        )
        let repository = try makeRepository(transport: transport, base: "https://example.com/api/")
        let query = "Rick & Morty + ñ?/#"

        _ = try await repository.searchCharacters(query: "  \(query) \n", page: 2)

        let requests = await transport.requests
        let url = try #require(requests.first?.url)
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        #expect(components.path == "/api/character")
        #expect(components.queryItems?.first(where: { $0.name == "name" })?.value == query.lowercased())
        #expect(components.queryItems?.first(where: { $0.name == "page" })?.value == "2")
        #expect(components.fragment == nil)
        #expect(components.percentEncodedQuery?.contains("%2B") == true)
        #expect(components.percentEncodedQuery?.contains("+") == false)
    }

    @Test(arguments: [0, -1])
    func rejectsInvalidPageWithoutRequestingNetwork(page: Int) async throws {
        let transport = try HTTPTransportSpy(response: APIResponseFixture.response())
        let repository = try makeRepository(transport: transport)
        await #expect(throws: CharacterRepositoryError.invalidRequest) {
            try await repository.searchCharacters(query: "Rick", page: page)
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test(arguments: ["file:///api", "https://example.com/api?key=value", "https://user:pass@example.com/api"])
    func rejectsInvalidBaseURLWithoutRequestingNetwork(base: String) async throws {
        let transport = try HTTPTransportSpy(response: APIResponseFixture.response())
        let repository = try makeRepository(transport: transport, base: base)
        await #expect(throws: CharacterRepositoryError.invalidRequest) {
            try await repository.searchCharacters(query: "Rick", page: 1)
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test
    func recognizesFilteredFirstPageNoMatches() async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.noMatches,
            response: APIResponseFixture.response(status: 404)
        )
        let repository = try makeRepository(transport: transport)

        let result = try await repository.searchCharacters(query: "no such character", page: 1)

        #expect(result == CharacterPage(characters: [], nextPage: nil))
    }

    @Test(arguments: ["", "   "])
    func generalList404IsNotEmptySuccess(query: String) async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.noMatches,
            response: APIResponseFixture.response(status: 404)
        )
        let repository = try makeRepository(transport: transport)
        await #expect(throws: CharacterRepositoryError.serviceFailure) {
            try await repository.searchCharacters(query: query, page: 1)
        }
    }

    @Test
    func laterPage404IsNotEmptySuccess() async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.noMatches,
            response: APIResponseFixture.response(status: 404)
        )
        let repository = try makeRepository(transport: transport)
        await #expect(throws: CharacterRepositoryError.serviceFailure) {
            try await repository.searchCharacters(query: "Rick", page: 2)
        }
    }

    @Test(arguments: [#"{"error":"Not found"}"#, "not JSON", #"{}"#])
    func unrecognized404BodyIsNotEmptySuccess(body: String) async throws {
        let transport = try HTTPTransportSpy(
            data: Foundation.Data(body.utf8),
            response: APIResponseFixture.response(status: 404)
        )
        let repository = try makeRepository(transport: transport)
        await #expect(throws: CharacterRepositoryError.serviceFailure) {
            try await repository.searchCharacters(query: "Rick", page: 1)
        }
    }

    @Test(arguments: [401, 403, 429, 500, 503])
    func mapsHTTPFailuresWithoutLeakingInfrastructureErrors(status: Int) async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.noMatches,
            response: APIResponseFixture.response(status: status)
        )
        let repository = try makeRepository(transport: transport)
        await #expect(throws: CharacterRepositoryError.serviceFailure) {
            try await repository.searchCharacters(query: "Rick", page: 1)
        }
    }

    @Test(arguments: [URLError.notConnectedToInternet, .networkConnectionLost, .cannotFindHost, .timedOut])
    func mapsConnectivityFailures(code: URLError.Code) async throws {
        let repository = try makeRepository(transport: HTTPTransportSpy(error: URLError(code)))
        await #expect(throws: CharacterRepositoryError.networkUnavailable) {
            try await repository.searchCharacters(query: "Rick", page: 1)
        }
    }

    @Test
    func securityFailureIsNotReportedAsOffline() async throws {
        let repository = try makeRepository(transport: HTTPTransportSpy(error: URLError(.secureConnectionFailed)))
        await #expect(throws: CharacterRepositoryError.serviceFailure) {
            try await repository.searchCharacters(query: "Rick", page: 1)
        }
    }

    @Test
    func mapsUnexpectedTransportFailure() async throws {
        let repository = try makeRepository(transport: HTTPTransportSpy(error: TestError.unexpected))
        await #expect(throws: CharacterRepositoryError.unexpected) {
            try await repository.searchCharacters(query: "Rick", page: 1)
        }
    }

    @Test(arguments: ["not JSON", #"{"results":[]}"#])
    func mapsDecodingFailure(body: String) async throws {
        let transport = try HTTPTransportSpy(data: Foundation.Data(body.utf8), response: APIResponseFixture.response())
        let repository = try makeRepository(transport: transport)
        await #expect(throws: CharacterRepositoryError.invalidData) {
            try await repository.searchCharacters(query: "Rick", page: 1)
        }
    }

    @Test
    func mapsNonHTTPResponse() async throws {
        let transport = try HTTPTransportSpy(response: URLResponse(
            url: APIResponseFixture.url(), mimeType: nil, expectedContentLength: 0, textEncodingName: nil
        ))
        let repository = try makeRepository(transport: transport)
        await #expect(throws: CharacterRepositoryError.invalidData) {
            try await repository.searchCharacters(query: "Rick", page: 1)
        }
    }

    @Test
    func mapsInvalidDomainData() async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.pageData(image: "file:///image"),
            response: APIResponseFixture.response()
        )
        let repository = try makeRepository(transport: transport)
        await #expect(throws: CharacterRepositoryError.invalidData) {
            try await repository.searchCharacters(query: "Rick", page: 1)
        }
    }

    @Test
    func cancellationIsNotConvertedIntoRepositoryFailure() async throws {
        let repository = try makeRepository(transport: HTTPTransportSpy(error: URLError(.cancelled)))
        await #expect(throws: CancellationError.self) {
            try await repository.searchCharacters(query: "Rick", page: 1)
        }
    }

    @Test
    func rejectsLateSuccessAfterCancellation() async throws {
        let transport = ControlledHTTPTransport()
        let repository = try makeRepository(transport: transport)
        let body = try APIResponseFixture.pageData()
        let response = try APIResponseFixture.response()
        let task = Task {
            try await repository.searchCharacters(query: "Rick", page: 1)
        }

        await transport.waitUntilRequested()
        task.cancel()
        await transport.succeed(data: body, response: response)

        await #expect(throws: CancellationError.self) { try await task.value }
    }

    private func makeRepository(
        transport: any HTTPTransport,
        base: String = "https://example.com/api"
    ) throws -> RickAndMortyCharacterRepository {
        try SearchRepositoryFixture(transport: transport, base: base).repository
    }
}
