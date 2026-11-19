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
    func olderRefreshSuccessOrFailureCannotReplaceNewerRefresh(olderFails: Bool) async throws {
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
        let newer = Task { try await fixture.repository.searchCharacters(
            query: "Rick",
            page: 1,
            policy: .reloadIgnoringCache
        ) }
        await transport.waitUntilRequested(count: 2)
        await transport.succeed(data: newBody, response: response, at: 1)
        _ = try await newer.value
        if olderFails {
            await transport.fail(with: URLError(.timedOut), at: 0)
            await #expect(throws: CharacterRepositoryError.networkUnavailable) { try await older.value }
        } else {
            await transport.succeed(data: oldBody, response: response, at: 0)
            _ = try await older.value
        }
        #expect(try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst).characters
            .first?.id == 2)
        #expect(await transport.requests.count == 2)
    }

    @Test(arguments: [false, true])
    func firstPageRefreshFencesPaginationFinishingBeforeOrAfterIt(paginationFinishesFirst: Bool) async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try SearchRepositoryFixture(transport: transport)
        let oldBody = try APIResponseFixture.pageData(next: nil, id: 1)
        let newBody = try APIResponseFixture.pageData(next: nil, id: 2)
        let freshPageBody = try APIResponseFixture.pageData(next: nil, id: 3)
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
        #expect(await fixture.cache.value(for: SearchCacheKey(query: "Rick", page: 2)) == nil)
        let freshPage = Task {
            try await fixture.repository.searchCharacters(query: "Rick", page: 2, policy: .cacheFirst)
        }
        await transport.waitUntilRequested(count: 3)
        await transport.succeed(data: freshPageBody, response: response, at: 2)
        #expect(try await freshPage.value.characters.first?.id == 3)
        #expect(try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst).characters
            .first?.id == 2)
        #expect(await transport.requests.count == 3)
    }

    @Test
    func cancelledRefreshCannotReplaceOrInvalidateExistingPages() async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try SearchRepositoryFixture(transport: transport)
        let old = try SearchRepositoryFixture.page(id: 1)
        let body = try APIResponseFixture.pageData(next: nil, id: 2)
        let response = try APIResponseFixture.response()
        let firstKey = SearchCacheKey(query: "Rick", page: 1)
        let secondKey = SearchCacheKey(query: "Rick", page: 2)
        try await fixture.cache.insert(old, for: firstKey)
        try await fixture.cache.insert(old, for: secondKey)
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
        #expect(await fixture.cache.value(for: secondKey) == old)
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

    @Test
    func unrelatedQueriesCanCommitIndependentlyInReverseOrder() async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try SearchRepositoryFixture(transport: transport)
        let firstBody = try APIResponseFixture.pageData(next: nil, id: 1)
        let secondBody = try APIResponseFixture.pageData(next: nil, id: 2)
        let response = try APIResponseFixture.response()
        let first = Task { try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst) }
        await transport.waitUntilRequested()
        let second = Task { try await fixture.repository.searchCharacters(query: "Morty", page: 1, policy: .cacheFirst)
        }
        await transport.waitUntilRequested(count: 2)
        await transport.succeed(data: secondBody, response: response, at: 1)
        _ = try await second.value
        await transport.succeed(data: firstBody, response: response, at: 0)
        _ = try await first.value
        #expect(try await fixture.repository.searchCharacters(query: "Rick", page: 1, policy: .cacheFirst).characters
            .first?.id == 1)
        #expect(try await fixture.repository.searchCharacters(query: "Morty", page: 1, policy: .cacheFirst).characters
            .first?.id == 2)
        #expect(await transport.requests.count == 2)
    }

    @Test
    func failedRefreshDoesNotInvalidatePaginationInProgress() async throws {
        let transport = ControlledHTTPTransport()
        let fixture = try SearchRepositoryFixture(transport: transport)
        let firstKey = SearchCacheKey(query: "Rick", page: 1)
        let old = try SearchRepositoryFixture.page(id: 1)
        let body = try APIResponseFixture.pageData(next: nil, id: 2)
        let response = try APIResponseFixture.response()
        try await fixture.cache.insert(old, for: firstKey)
        let pagination = Task { try await fixture.repository.searchCharacters(
            query: "Rick",
            page: 2,
            policy: .cacheFirst
        ) }
        await transport.waitUntilRequested()
        let refresh = Task { try await fixture.repository.searchCharacters(
            query: "Rick",
            page: 1,
            policy: .reloadIgnoringCache
        ) }
        await transport.waitUntilRequested(count: 2)
        await transport.fail(with: URLError(.timedOut), at: 1)
        await #expect(throws: CharacterRepositoryError.networkUnavailable) { try await refresh.value }
        await transport.succeed(data: body, response: response, at: 0)
        _ = try await pagination.value
        #expect(await fixture.cache.value(for: firstKey) == old)
        #expect(try await fixture.repository.searchCharacters(query: "Rick", page: 2, policy: .cacheFirst).characters
            .first?.id == 2)
        #expect(await transport.requests.count == 2)
    }
}
