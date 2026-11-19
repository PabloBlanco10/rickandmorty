@testable import Data
import Domain
import Foundation
import Testing

struct CharacterSearchCacheTests {
    @Test
    func normalizedQueryCacheHitMakesNoAdditionalRequest() async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.pageData(),
            response: APIResponseFixture.response()
        )
        let fixture = try SearchRepositoryFixture(transport: transport)
        let first = try await fixture.repository.searchCharacters(query: "  Rick\n", page: 1, policy: .cacheFirst)
        let second = try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst)
        #expect(first == second)
        #expect(await transport.requests.count == 1)
    }

    @Test
    func expirationUsesConfiguredTTLAndExactBoundary() async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.pageData(),
            response: APIResponseFixture.response()
        )
        let fixture = try SearchRepositoryFixture(transport: transport, ttl: .seconds(5))
        _ = try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst)
        await fixture.time.advance(by: .seconds(5) - .nanoseconds(1))
        _ = try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst)
        #expect(await transport.requests.count == 1)
        await fixture.time.advance(by: .nanoseconds(1))
        _ = try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst)
        #expect(await transport.requests.count == 2)
    }

    @Test
    func successfulRefreshReplacesValueAndRestartsTTL() async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.pageData(next: nil, id: 2),
            response: APIResponseFixture.response()
        )
        let fixture = try SearchRepositoryFixture(transport: transport, ttl: .seconds(10))
        let key = SearchCacheKey(query: "Rick", page: 1)
        try await fixture.cache.insert(SearchRepositoryFixture.page(id: 1), for: key)
        await fixture.time.advance(by: .seconds(9))

        let refreshed = try await fixture.repository.searchCharacters(
            query: "Rick",
            page: 1,
            policy: .reloadIgnoringCache
        )
        #expect(refreshed.characters.first?.id == 2)
        await fixture.time.advance(by: .seconds(1))
        let cached = try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst)
        #expect(cached == refreshed)
        #expect(await transport.requests.count == 1)
        await fixture.time.advance(by: .seconds(9))
        #expect(await fixture.cache.value(for: key) == nil)
    }

    @Test
    func failedRefreshPreservesPagesAndTheirOriginalExpiration() async throws {
        let transport = HTTPTransportSpy(error: URLError(.notConnectedToInternet))
        let fixture = try SearchRepositoryFixture(transport: transport)
        let firstKey = SearchCacheKey(query: "Rick", page: 1)
        let secondKey = SearchCacheKey(query: "Rick", page: 2)
        let old = try SearchRepositoryFixture.page()
        try await fixture.cache.insert(old, for: firstKey)
        try await fixture.cache.insert(old, for: secondKey)
        await fixture.time.advance(by: .seconds(179))

        await #expect(throws: CharacterRepositoryError.networkUnavailable) {
            try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .reloadIgnoringCache)
        }
        #expect(try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst) == old)
        #expect(try await fixture.repository.searchCharacters(query: "Rick", page: 2, policy: .cacheFirst) == old)
        #expect(await transport.requests.count == 1)
        await fixture.time.advance(by: .seconds(1))
        #expect(await fixture.cache.value(for: firstKey) == nil)
        #expect(await fixture.cache.value(for: secondKey) == nil)
    }

    @Test
    func queryPageAndCaseKeysAreIndependent() async throws {
        let transport = try HTTPTransportSpy(response: APIResponseFixture.response())
        let fixture = try SearchRepositoryFixture(transport: transport)
        let keys = [
            SearchCacheKey(query: "Rick", page: 1), SearchCacheKey(query: "Rick", page: 2),
            SearchCacheKey(query: "Morty", page: 1), SearchCacheKey(query: "rick", page: 1)
        ]
        for (index, key) in keys.enumerated() {
            try await fixture.cache.insert(SearchRepositoryFixture.page(id: index + 1), for: key)
        }
        for (index, key) in keys.enumerated() {
            let result = try await fixture.repository.searchCharacters(
                query: key.query,
                page: key.page,
                policy: .cacheFirst
            )
            #expect(result.characters.first?.id == index + 1)
        }
        #expect(await transport.requests.isEmpty)
    }

    @Test(arguments: [FetchPolicy.cacheFirst, .reloadIgnoringCache])
    func firstPageReplacementPreservesLaterPagesAndTheirExpiration(policy: FetchPolicy) async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.pageData(next: nil, id: 9),
            response: APIResponseFixture.response()
        )
        let fixture = try SearchRepositoryFixture(transport: transport, ttl: .seconds(10))
        let firstKey = SearchCacheKey(query: "Rick", page: 1)
        let secondKey = SearchCacheKey(query: "Rick", page: 2)
        let old = try SearchRepositoryFixture.page()
        try await fixture.cache.insert(old, for: firstKey)
        await fixture.time.advance(by: .seconds(5))
        try await fixture.cache.insert(old, for: secondKey)
        await fixture.time.advance(by: .seconds(5))
        // Page 1 has expired; page 2 still has five seconds remaining.
        let refreshed = try await fixture.repository.searchCharacters(query: " Rick ", page: 1, policy: policy)
        #expect(refreshed.characters.first?.id == 9)
        #expect(try await fixture.repository.searchCharacters(query: "Rick", page: 2, policy: .cacheFirst) == old)
        #expect(await transport.requests.count == 1)

        await fixture.time.advance(by: .seconds(5))
        #expect(await fixture.cache.value(for: secondKey) == nil)
        #expect(await fixture.cache.value(for: firstKey) == refreshed)
    }

    @Test(arguments: [1, 2])
    func refreshingOnePagePreservesOtherPages(refreshedPage: Int) async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.pageData(next: nil, id: 9),
            response: APIResponseFixture.response()
        )
        let fixture = try SearchRepositoryFixture(transport: transport)
        let old = try SearchRepositoryFixture.page()
        for page in 1 ... 3 {
            try await fixture.cache.insert(old, for: SearchCacheKey(query: "Rick", page: page))
        }

        _ = try await fixture.repository.searchCharacters(
            query: "Rick",
            page: refreshedPage,
            policy: .reloadIgnoringCache
        )

        for page in 1 ... 3 {
            let cached = await fixture.cache.value(for: SearchCacheKey(query: "Rick", page: page))
            #expect(cached?.characters.first?.id == (page == refreshedPage ? 9 : old.characters.first?.id))
        }
    }

    @Test
    func cachesRecognizedEmptyResultsWithoutChangingOtherPages() async throws {
        let transport = try HTTPTransportSpy(
            data: APIResponseFixture.noMatches,
            response: APIResponseFixture.response(status: 404)
        )
        let fixture = try SearchRepositoryFixture(transport: transport)
        let secondKey = SearchCacheKey(query: "Rick", page: 2)
        let old = try SearchRepositoryFixture.page()
        try await fixture.cache.insert(old, for: secondKey)
        let empty = try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .reloadIgnoringCache)
        #expect(empty == CharacterPage(characters: [], nextPage: nil))
        #expect(try await fixture.repository.searchCharacters(query: " Rick ", page: 1, policy: .cacheFirst) == empty)
        #expect(await fixture.cache.value(for: secondKey) == old)
        #expect(await transport.requests.count == 1)
    }

    @Test
    func failuresAreNotCached() async throws {
        let transport = HTTPTransportSpy(error: URLError(.timedOut))
        let fixture = try SearchRepositoryFixture(transport: transport)
        for _ in 0 ..< 2 {
            await #expect(throws: CharacterRepositoryError.networkUnavailable) {
                try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst)
            }
        }
        #expect(await fixture.cache.value(for: SearchCacheKey(query: "Rick", page: 1)) == nil)
        #expect(await transport.requests.count == 2)
    }

    @Test
    func invalidPageCannotBeServedFromCache() async throws {
        let transport = try HTTPTransportSpy(response: APIResponseFixture.response())
        let fixture = try SearchRepositoryFixture(transport: transport)
        try await fixture.cache.insert(SearchRepositoryFixture.page(), for: SearchCacheKey(query: "Rick", page: 0))
        await #expect(throws: CharacterRepositoryError.invalidRequest) {
            try await fixture.repository.searchCharacters(query: "Rick", page: 0, policy: .cacheFirst)
        }
        #expect(await transport.requests.isEmpty)
    }
}
