import Domain
@testable import Presentation
import Testing

@MainActor
struct CharacterRefreshTests {
    @Test
    func refreshBypassesCacheAndReplacesVisiblePaginationOnlyAfterSuccess() async {
        let fixture = SearchViewModelFixture()
        await fixture.load(ids: [1, 2], nextPage: 4)
        let refresh = Task { await fixture.model.refresh() }
        await fixture.repository.waitUntilRequested(count: 2)
        #expect(fixture.model.isRefreshing)
        #expect(fixture.ids == [1, 2])
        #expect(fixture.model.nextPage == 4)
        #expect(await fixture.repository.requests.last == .init(query: "", page: 1, policy: .reloadIgnoringCache))
        await fixture.model.loadNextPage(approaching: 1)
        #expect(await fixture.repository.requests.count == 2)
        await fixture.repository.succeed(ids: [3], nextPage: 2, at: 1)
        await refresh.value
        #expect(fixture.ids == [3])
        #expect(fixture.model.nextPage == 2)
        #expect(!fixture.model.isRefreshing)
    }

    @Test
    func failedRefreshPreservesVisibleContentAndCanBeRetried() async {
        let fixture = SearchViewModelFixture()
        await fixture.load(nextPage: 4)
        let refresh = Task { await fixture.model.refresh() }
        await fixture.repository.waitUntilRequested(count: 2)
        await fixture.repository.fail(.networkUnavailable, at: 1)
        await refresh.value
        #expect(fixture.ids == [1])
        #expect(fixture.model.nextPage == 4)
        #expect(fixture.model.refreshError == .connection)
        #expect(!fixture.model.isRefreshing)
        let retry = Task { await fixture.model.refresh() }
        await fixture.repository.waitUntilRequested(count: 3)
        #expect(fixture.model.refreshError == nil)
        await fixture.repository.succeed(ids: [2], at: 2)
        await retry.value
        #expect(fixture.ids == [2])
    }

    @Test
    func refreshSupersedesPaginationAndOldCleanupCannotStopItsProgress() async {
        let fixture = SearchViewModelFixture()
        await fixture.load()
        let pagination = Task { await fixture.model.loadNextPage(approaching: 1) }
        await fixture.repository.waitUntilRequested(count: 2)
        let refresh = Task { await fixture.model.refresh() }
        await fixture.repository.waitUntilRequested(count: 3)
        await fixture.repository.succeed(ids: [2], nextPage: 3, at: 1)
        await pagination.value
        #expect(fixture.model.isRefreshing)
        #expect(fixture.ids == [1])
        await fixture.repository.succeed(ids: [3], nextPage: 2, at: 2)
        await refresh.value
        #expect(fixture.ids == [3])
        #expect(fixture.model.nextPage == 2)
    }

    @Test
    func queryChangeInvalidatesRefreshBeforeNewDebounceFinishes() async throws {
        let debounce = ControlledDebounce()
        let fixture = SearchViewModelFixture(debounce: { await debounce.wait() })
        await fixture.load()
        let refresh = Task { await fixture.model.refresh() }
        await fixture.repository.waitUntilRequested(count: 2)
        fixture.model.updateSearchText("Morty")
        let search = try #require(fixture.model.operation)
        await debounce.waitUntilRequested()
        await fixture.repository.succeed(ids: [2], at: 1)
        await refresh.value
        #expect(fixture.isLoading)
        #expect(fixture.ids == nil)
        #expect(!fixture.model.isRefreshing)
        await debounce.release()
        await fixture.repository.waitUntilRequested(count: 3)
        await fixture.repository.succeed(ids: [3], at: 2)
        await search.value
        #expect(fixture.ids == [3])
    }

    @Test
    func cancelledRefreshPreservesContentWithoutError() async {
        let fixture = SearchViewModelFixture()
        await fixture.load()
        let refresh = Task { await fixture.model.refresh() }
        await fixture.repository.waitUntilRequested(count: 2)
        refresh.cancel()
        await fixture.repository.succeed(ids: [2], at: 1)
        await refresh.value
        #expect(fixture.ids == [1])
        #expect(fixture.model.nextPage == 2)
        #expect(fixture.model.refreshError == nil)
        #expect(!fixture.model.isRefreshing)
    }
}
