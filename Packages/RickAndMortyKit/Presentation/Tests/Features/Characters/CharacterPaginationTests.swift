import Domain
@testable import Presentation
import Testing

@MainActor
struct CharacterPaginationTests {
    @Test
    func onlyNewNearEndAppearancesCanAdvancePagination() async {
        let fixture = SearchViewModelFixture()
        await fixture.load(ids: Array(1 ... 20))
        await fixture.viewModel.loadNextPage(approaching: 1)
        await fixture.viewModel.loadNextPage(approaching: 17)
        #expect(await fixture.repository.requests.count == 1)
        let page = Task { await fixture.viewModel.loadNextPage(approaching: 18) }
        await fixture.repository.waitUntilRequested(count: 2)
        await fixture.viewModel.loadNextPage(approaching: 19)
        #expect(await fixture.repository.requests.count == 2)
        await fixture.repository.succeed(ids: Array(21 ... 40), nextPage: 3, at: 1)
        await page.value
        // Metadata changed, but old rows reappearing during upward scrolling
        // are no longer near the end of the expanded list.
        await fixture.viewModel.loadNextPage(approaching: 20)
        await fixture.viewModel.loadNextPage(approaching: 1)
        #expect(await fixture.repository.requests.count == 2)
        let next = Task { await fixture.viewModel.loadNextPage(approaching: 38) }
        await fixture.repository.waitUntilRequested(count: 3)
        #expect(await fixture.repository.requests.last?.page == 3)
        await fixture.repository.succeed(ids: [41], at: 2)
        await next.value
        #expect(fixture.ids?.count == 41)
    }

    @Test
    func paginationPreventsDuplicatesAppendsUniqueIDsAndStopsAtEnd() async {
        let fixture = SearchViewModelFixture()
        await fixture.load(ids: [1, 2])
        let pagination = Task { await fixture.viewModel.loadNextPage(approaching: 1) }
        await fixture.repository.waitUntilRequested(count: 2)
        #expect(fixture.viewModel.isLoadingNextPage)
        #expect(fixture.ids == [1, 2])
        await fixture.viewModel.loadNextPage(approaching: 1)
        #expect(await fixture.repository.requests.count == 2)
        #expect(await fixture.repository.requests.last == .init(query: "", page: 2, policy: .cacheFirst))
        await fixture.repository.succeed(ids: [2, 3], at: 1)
        await pagination.value
        #expect(fixture.ids == [1, 2, 3])
        #expect(!fixture.viewModel.isLoadingNextPage)
        #expect(fixture.viewModel.nextPage == nil)
        await fixture.viewModel.loadNextPage(approaching: 1)
        #expect(await fixture.repository.requests.count == 2)
    }

    @Test
    func paginationFailurePreservesContentAndRequiresExplicitRetry() async {
        let fixture = SearchViewModelFixture()
        await fixture.load()
        let pagination = Task { await fixture.viewModel.loadNextPage(approaching: 1) }
        await fixture.repository.waitUntilRequested(count: 2)
        await fixture.repository.fail(.networkUnavailable, at: 1)
        await pagination.value
        #expect(fixture.ids == [1])
        #expect(fixture.viewModel.nextPage == 2)
        #expect(fixture.viewModel.paginationError == .connection)
        await fixture.viewModel.loadNextPage(approaching: 1)
        #expect(await fixture.repository.requests.count == 2)
        let retry = Task { await fixture.viewModel.retryPagination() }
        await fixture.repository.waitUntilRequested(count: 3)
        #expect(fixture.viewModel.paginationError == nil)
        #expect(await fixture.repository.requests.last?.page == 2)
        await fixture.repository.succeed(ids: [2], at: 2)
        await retry.value
        #expect(fixture.ids == [1, 2])
    }

    @Test
    func queryChangePreventsOldPaginationFromAppending() async throws {
        let fixture = SearchViewModelFixture()
        await fixture.load()
        let pagination = Task { await fixture.viewModel.loadNextPage(approaching: 1) }
        await fixture.repository.waitUntilRequested(count: 2)
        fixture.viewModel.updateSearchText("Morty")
        let search = try #require(fixture.viewModel.operation)
        await fixture.repository.waitUntilRequested(count: 3)
        await fixture.repository.succeed(ids: [3], at: 2)
        await search.value
        await fixture.repository.succeed(ids: [2], nextPage: 3, at: 1)
        await pagination.value
        #expect(await fixture.repository.cancelledRequests.contains(1))
        #expect(fixture.ids == [3])
        #expect(fixture.viewModel.nextPage == nil)
        #expect(!fixture.viewModel.isLoadingNextPage)
    }

    @Test
    func disappearanceCancelsPaginationWithoutDiscardingContentOrShowingError() async {
        let fixture = SearchViewModelFixture()
        await fixture.load()
        let pagination = Task { await fixture.viewModel.loadNextPage(approaching: 1) }
        await fixture.repository.waitUntilRequested(count: 2)
        fixture.viewModel.cancel()
        await fixture.repository.fail(.serviceFailure, at: 1)
        await pagination.value
        #expect(fixture.ids == [1])
        #expect(fixture.viewModel.nextPage == 2)
        #expect(fixture.viewModel.paginationError == nil)
        #expect(!fixture.viewModel.isLoadingNextPage)
    }
}
