@testable import Data
import Domain
import Foundation
import Testing

struct CharacterSearchReentrancyTests {
    @Test
    func olderCommitSuspendedInClockCannotOverwriteNewerRefresh() async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try SearchRepositoryFixture(transport: transport)
        let oldBody = try APIResponseFixture.pageData(next: nil, id: 1)
        let newBody = try APIResponseFixture.pageData(next: nil, id: 2)
        let response = try APIResponseFixture.response()
        let older = Task { try await fixture.repository.searchCharacters(
            query: "Rick",
            page: 1,
            policy: .reloadIgnoringCache
        ) }
        await transport.waitUntilRequested()
        await fixture.time.suspendNextRead()
        await transport.succeed(data: oldBody, response: response, at: 0)
        await fixture.time.waitUntilReadSuspends()

        let newer = Task { try await fixture.repository.searchCharacters(
            query: "Rick",
            page: 1,
            policy: .reloadIgnoringCache
        ) }
        await transport.waitUntilRequested(count: 2)
        await transport.succeed(data: newBody, response: response, at: 1)
        _ = try await newer.value
        await fixture.time.resumeRead()
        _ = try await older.value

        #expect(try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst).characters
            .first?.id == 2)
        #expect(await transport.requests.count == 2)
    }

    @Test
    func cancellationDuringRepositoryCommitPreservesOldPages() async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try SearchRepositoryFixture(transport: transport)
        let old = try SearchRepositoryFixture.page()
        let body = try APIResponseFixture.pageData(next: nil, id: 2)
        let response = try APIResponseFixture.response()
        let firstKey = SearchCacheKey(query: "Rick", page: 1)
        let secondKey = SearchCacheKey(query: "Rick", page: 2)
        try await fixture.cache.insert(old, for: firstKey)
        try await fixture.cache.insert(old, for: secondKey)
        let refresh = Task { try await fixture.repository.searchCharacters(
            query: "Rick",
            page: 1,
            policy: .reloadIgnoringCache
        ) }
        await transport.waitUntilRequested()
        await fixture.time.suspendNextRead()
        await transport.succeed(data: body, response: response)
        await fixture.time.waitUntilReadSuspends()
        refresh.cancel()
        await fixture.time.resumeRead()

        await #expect(throws: CancellationError.self) { try await refresh.value }
        #expect(await fixture.cache.value(for: firstKey) == old)
        #expect(await fixture.cache.value(for: secondKey) == old)
    }
}
