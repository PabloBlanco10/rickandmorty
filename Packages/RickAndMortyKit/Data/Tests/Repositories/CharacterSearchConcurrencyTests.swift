@testable import Data
import Domain
import Foundation
import Testing

struct CharacterSearchConcurrencyTests {
    @Test
    func olderSearchCannotOverwriteSuccessfulRefresh() async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try SearchRepositoryFixture(transport: transport)
        let oldBody = try APIResponseFixture.pageData(next: nil, id: 1)
        let newBody = try APIResponseFixture.pageData(next: nil, id: 2)
        let response = try APIResponseFixture.response()
        let older = Task { try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst) }
        await transport.waitUntilRequested()
        let refresh = Task { try await fixture.repository.searchCharacters(
            query: "Rick",
            page: 1,
            policy: .reloadIgnoringCache
        ) }
        await transport.waitUntilRequested(count: 2)
        await transport.succeed(data: newBody, response: response, at: 1)
        #expect(try await refresh.value.characters.first?.id == 2)
        await transport.succeed(data: oldBody, response: response, at: 0)
        #expect(try await older.value.characters.first?.id == 1)
        #expect(try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst).characters
            .first?.id == 2)
        #expect(await transport.requests.count == 2)
    }

    @Test(arguments: [false, true])
    func firstPageRefreshLeavesConcurrentPaginationIndependent(paginationFinishesFirst: Bool) async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try SearchRepositoryFixture(transport: transport)
        let oldBody = try APIResponseFixture.pageData(next: nil, id: 1)
        let newBody = try APIResponseFixture.pageData(next: nil, id: 2)
        let response = try APIResponseFixture.response()
        let pagination = Task { try await fixture.repository.searchCharacters(
            query: "Rick",
            page: 2,
            policy: .cacheFirst
        ) }
        await transport.waitUntilRequested()
        let refresh = Task { try await fixture.repository.searchCharacters(
            query: " Rick ",
            page: 1,
            policy: .reloadIgnoringCache
        ) }
        await transport.waitUntilRequested(count: 2)
        if paginationFinishesFirst {
            await transport.succeed(data: oldBody, response: response, at: 0)
            _ = try await pagination.value
        }
        await transport.succeed(data: newBody, response: response, at: 1)
        _ = try await refresh.value
        if !paginationFinishesFirst {
            await transport.succeed(data: oldBody, response: response, at: 0)
            _ = try await pagination.value
        }
        #expect(try await fixture.repository.searchCharacters(query: "Rick", page: 2, policy: .cacheFirst).characters
            .first?.id == 1)
        #expect(try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst).characters
            .first?.id == 2)
        #expect(await transport.requests.count == 2)
    }

    @Test
    func cancelledRefreshWithLateSuccessPreservesValueAndExpiration() async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try SearchRepositoryFixture(transport: transport)
        let old = try SearchRepositoryFixture.page(id: 1)
        let body = try APIResponseFixture.pageData(next: nil, id: 2)
        let response = try APIResponseFixture.response()
        let firstKey = SearchCacheKey(query: "Rick", page: 1)
        try await fixture.cache.insert(old, for: firstKey)
        await fixture.time.advance(by: .seconds(179))
        let task = Task { try await fixture.repository.searchCharacters(
            query: "Rick",
            page: 1,
            policy: .reloadIgnoringCache
        ) }
        await transport.waitUntilRequested()
        task.cancel()
        await transport.succeed(data: body, response: response)
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(await fixture.cache.value(for: firstKey) == old)
        await fixture.time.advance(by: .seconds(1))
        #expect(await fixture.cache.value(for: firstKey) == nil)
    }

    @Test
    func cancelledOlderRequestCleanupDoesNotRevokeNewerWrite() async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try SearchRepositoryFixture(transport: transport)
        let body = try APIResponseFixture.pageData(next: nil, id: 2)
        let response = try APIResponseFixture.response()
        let older = Task { try await fixture.repository.searchCharacters(
            query: "Rick",
            page: 1,
            policy: .reloadIgnoringCache
        ) }
        await transport.waitUntilRequested()
        let newer = Task { try await fixture.repository.searchCharacters(
            query: "Rick",
            page: 1,
            policy: .reloadIgnoringCache
        ) }
        await transport.waitUntilRequested(count: 2)
        older.cancel()
        await transport.succeed(data: body, response: response, at: 0)
        await #expect(throws: CancellationError.self) { try await older.value }
        await transport.succeed(data: body, response: response, at: 1)
        _ = try await newer.value
        #expect(try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst).characters
            .first?.id == 2)
        #expect(await transport.requests.count == 2)
    }
}
