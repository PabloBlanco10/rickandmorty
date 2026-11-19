import Domain
@testable import Presentation
import Testing

@MainActor
struct CharacterPaginationTests {
    @Test
    func paginationPreventsDuplicatesAppendsUniqueIDsAndStopsAtEnd() async {
        let fixture = SearchViewModelFixture()
        await fixture.load(ids: [1, 2])
        let pagination = Task { await fixture.model.loadNextPage() }
        await fixture.repository.waitUntilRequested(count: 2)
        #expect(fixture.model.isLoadingNextPage)
        #expect(fixture.ids == [1, 2])
        await fixture.model.loadNextPage()
        #expect(await fixture.repository.requests.count == 2)
        #expect(await fixture.repository.requests.last == .init(query: "", page: 2, policy: .cacheFirst))
        await fixture.repository.succeed(ids: [2, 3], at: 1)
        await pagination.value
        #expect(fixture.ids == [1, 2, 3])
        #expect(!fixture.model.isLoadingNextPage)
        #expect(fixture.model.nextPage == nil)
        await fixture.model.loadNextPage()
        #expect(await fixture.repository.requests.count == 2)
    }

    @Test
    func paginationFailurePreservesContentAndRequiresExplicitRetry() async {
        let fixture = SearchViewModelFixture()
        await fixture.load()
        let pagination = Task { await fixture.model.loadNextPage() }
        await fixture.repository.waitUntilRequested(count: 2)
        await fixture.repository.fail(.networkUnavailable, at: 1)
        await pagination.value
        #expect(fixture.ids == [1])
        #expect(fixture.model.nextPage == 2)
        #expect(fixture.model.paginationError == .connection)
        await fixture.model.loadNextPage()
        #expect(await fixture.repository.requests.count == 2)
        let retry = Task { await fixture.model.retryPagination() }
        await fixture.repository.waitUntilRequested(count: 3)
        #expect(fixture.model.paginationError == nil)
        #expect(await fixture.repository.requests.last?.page == 2)
        await fixture.repository.succeed(ids: [2], at: 2)
        await retry.value
        #expect(fixture.ids == [1, 2])
    }

    @Test
    func queryChangePreventsOldPaginationFromAppending() async throws {
        let fixture = SearchViewModelFixture()
        await fixture.load()
        let pagination = Task { await fixture.model.loadNextPage() }
        await fixture.repository.waitUntilRequested(count: 2)
        let search = try #require(fixture.model.updateSearchText("Morty"))
        await fixture.repository.waitUntilRequested(count: 3)
        await fixture.repository.succeed(ids: [3], at: 2)
        await search.value
        await fixture.repository.succeed(ids: [2], nextPage: 3, at: 1)
        await pagination.value
        #expect(await fixture.repository.cancelledRequests.contains(1))
        #expect(fixture.ids == [3])
        #expect(fixture.model.nextPage == nil)
        #expect(!fixture.model.isLoadingNextPage)
    }

    @Test
    func disappearanceCancelsPaginationWithoutDiscardingContentOrShowingError() async {
        let fixture = SearchViewModelFixture()
        await fixture.load()
        let pagination = Task { await fixture.model.loadNextPage() }
        await fixture.repository.waitUntilRequested(count: 2)
        fixture.model.cancel()
        await fixture.repository.fail(.serviceFailure, at: 1)
        await pagination.value
        #expect(fixture.ids == [1])
        #expect(fixture.model.nextPage == 2)
        #expect(fixture.model.paginationError == nil)
        #expect(!fixture.model.isLoadingNextPage)
    }
}
