@testable import Data
import Domain
import Foundation
import Testing

struct CharacterDetailRepositoryTests {
    @Test(arguments: ["https://example.com/api", "https://example.com/api/"])
    func buildsDetailURLMapsFieldsAndServesCacheWithoutNetworking(base: String) async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.characterData(id: 7),
            response: APIResponseFixture.response()
        )
        let fixture = try DetailRepositoryFixture(transport: transport, base: base)
        let character = try await fixture.repository.character(id: 7, policy: .cacheFirst)
        #expect(character.id == 7)
        #expect(character.name == "Rick Sanchez")
        #expect(character.imageURL.absoluteString == "https://example.com/1.jpeg")
        #expect(character.status == .alive)
        #expect(character.species == "Human")
        #expect(character.gender == .male)
        #expect(character.origin == "Earth")
        #expect(character.location == "Citadel")
        #expect(try await fixture.repository.character(id: 7, policy: .cacheFirst) == character)
        #expect(await transport.requests.count == 1)
        #expect(await transport.requests.first?.url?.absoluteString == "https://example.com/api/character/7")
        #expect(await transport.requests.first?.httpMethod == "GET")
    }

    @Test(arguments: [0, -1])
    func rejectsInvalidIDsBeforeNetworking(id: Int) async throws {
        let transport = try HTTPTransportSpy(response: APIResponseFixture.response())
        let fixture = try DetailRepositoryFixture(transport: transport)
        await #expect(throws: CharacterRepositoryError.invalidRequest) {
            try await fixture.repository.character(id: id, policy: .cacheFirst)
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test(arguments: [true, false])
    func cachedDetailDoesNotBypassEndpointValidation(invalidID: Bool) async throws {
        let transport = try HTTPTransportSpy(response: APIResponseFixture.response())
        let id = invalidID ? 0 : 1
        let base = invalidID ? "https://example.com/api" : "https://example.com/api?unexpected=query"
        let fixture = try DetailRepositoryFixture(transport: transport, base: base)
        let character = try #require(SearchRepositoryFixture.page().characters.first)
        try await fixture.cache.insert(character, for: id)

        await #expect(throws: CharacterRepositoryError.invalidRequest) {
            try await fixture.repository.character(id: id, policy: .cacheFirst)
        }
        #expect(await transport.requests.isEmpty)
        #expect(await fixture.cache.value(for: id) == character)
    }

    @Test(arguments: [404, 429, 500])
    func statusFailuresIncludingNoMatch404AreNotCached(status: Int) async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.noMatches,
            response: APIResponseFixture.response(status: status)
        )
        let fixture = try DetailRepositoryFixture(transport: transport)
        for _ in 0 ..< 2 {
            await #expect(throws: CharacterRepositoryError.serviceFailure) {
                try await fixture.repository.character(id: 1, policy: .cacheFirst)
            }
        }
        #expect(await transport.requests.count == 2)
        #expect(await fixture.cache.value(for: 1) == nil)
    }

    @Test(arguments: [0, 2])
    func rejectsInvalidOrMismatchedResponseIDs(id: Int) async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.characterData(id: id),
            response: APIResponseFixture.response()
        )
        let fixture = try DetailRepositoryFixture(transport: transport)
        await #expect(throws: CharacterRepositoryError.invalidData) {
            try await fixture.repository.character(id: 1, policy: .cacheFirst)
        }
        #expect(await fixture.cache.value(for: 1) == nil)
    }

    @Test
    func expiryAndForcedReloadEachRequireNetworking() async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.characterData(),
            response: APIResponseFixture.response()
        )
        let fixture = try DetailRepositoryFixture(transport: transport, ttl: .seconds(5))
        _ = try await fixture.repository.character(id: 1, policy: .cacheFirst)
        await fixture.time.advance(by: .seconds(5) - .nanoseconds(1))
        _ = try await fixture.repository.character(id: 1, policy: .cacheFirst)
        #expect(await transport.requests.count == 1)
        await fixture.time.advance(by: .nanoseconds(1))
        _ = try await fixture.repository.character(id: 1, policy: .cacheFirst)
        _ = try await fixture.repository.character(id: 1, policy: .reloadIgnoringCache)
        #expect(await transport.requests.count == 3)
    }

    @Test
    func failedReloadPreservesValueAndOriginalExpiry() async throws {
        let transport = HTTPTransportSpy(error: URLError(.notConnectedToInternet))
        let fixture = try DetailRepositoryFixture(transport: transport)
        let character = try #require(SearchRepositoryFixture.page().characters.first)
        try await fixture.cache.insert(character, for: 1)
        await fixture.time.advance(by: .seconds(179))
        await #expect(throws: CharacterRepositoryError.networkUnavailable) {
            try await fixture.repository.character(id: 1, policy: .reloadIgnoringCache)
        }
        #expect(try await fixture.repository.character(id: 1, policy: .cacheFirst) == character)
        #expect(await transport.requests.count == 1)
        await fixture.time.advance(by: .seconds(1))
        #expect(await fixture.cache.value(for: 1) == nil)
    }

    @Test
    func cancelledLateSuccessPreservesCachedCharacter() async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try DetailRepositoryFixture(transport: transport)
        let old = try #require(SearchRepositoryFixture.page().characters.first)
        try await fixture.cache.insert(old, for: 1)
        let request = Task { try await fixture.repository.character(id: 1, policy: .reloadIgnoringCache) }
        await transport.waitUntilRequested()
        request.cancel()
        try await transport.succeed(
            data: APIResponseFixture.characterData(name: "Replacement"),
            response: APIResponseFixture.response()
        )
        await #expect(throws: CancellationError.self) { try await request.value }
        #expect(await fixture.cache.value(for: 1) == old)
    }

    @Test
    func olderResponseCannotOverwriteNewerDetailCacheEntry() async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try DetailRepositoryFixture(transport: transport)
        let older = Task { try await fixture.repository.character(id: 1, policy: .reloadIgnoringCache) }
        await transport.waitUntilRequested()
        let newer = Task { try await fixture.repository.character(id: 1, policy: .reloadIgnoringCache) }
        await transport.waitUntilRequested(count: 2)
        try await transport.succeed(
            data: APIResponseFixture.characterData(name: "New Rick"), response: APIResponseFixture.response(), at: 1
        )
        #expect(try await newer.value.name == "New Rick")
        try await transport.succeed(
            data: APIResponseFixture.characterData(name: "Old Rick"), response: APIResponseFixture.response(), at: 0
        )
        #expect(try await older.value.name == "Old Rick")
        #expect(try await fixture.repository.character(id: 1, policy: .cacheFirst).name == "New Rick")
        #expect(await transport.requests.count == 2)
    }

    @Test
    func searchAndDetailCachesRemainIndependent() async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try DetailRepositoryFixture(transport: transport)
        let search = Task { try await fixture.repository.searchCharacters(query: "", page: 1, policy: .cacheFirst) }
        await transport.waitUntilRequested()
        try await transport.succeed(
            data: APIResponseFixture.pageData(next: nil),
            response: APIResponseFixture.response()
        )
        _ = try await search.value
        let detail = Task { try await fixture.repository.character(id: 1, policy: .cacheFirst) }
        await transport.waitUntilRequested(count: 2)
        try await transport.succeed(
            data: APIResponseFixture.characterData(name: "Detail Rick"),
            response: APIResponseFixture.response(),
            at: 1
        )
        _ = try await detail.value
        #expect(try await fixture.repository.searchCharacters(query: "", page: 1, policy: .cacheFirst).characters.first?
            .name == "Rick Sanchez")
        #expect(try await fixture.repository.character(id: 1, policy: .cacheFirst).name == "Detail Rick")
        #expect(await transport.requests.count == 2)
    }
}
