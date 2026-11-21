import Domain
@testable import Presentation
import Testing

@MainActor
struct CharactersViewModelTests {
    @Test
    func initialLoadRequestsGeneralListOnce() async {
        let fixture = SearchViewModelFixture()
        let load = Task { await fixture.viewModel.loadInitial() }
        await fixture.repository.waitUntilRequested()
        #expect(fixture.isLoading)
        #expect(await fixture.repository.requests == [.init(query: "", page: 1)])
        await fixture.repository.succeed(ids: [1, 2], nextPage: 2)
        await load.value
        #expect(fixture.ids == [1, 2])
        #expect(fixture.viewModel.nextPage == 2)
        await fixture.viewModel.loadInitial()
        #expect(await fixture.repository.requests.count == 1)
    }

    @Test
    func emptyResultsAreLoadedWithoutError() async {
        let fixture = SearchViewModelFixture()
        await fixture.load(ids: [], nextPage: nil)
        #expect(fixture.ids == [])
        #expect(fixture.failure == nil)
        #expect(fixture.viewModel.nextPage == nil)
    }

    @Test
    func searchFailureHasAnImmediateRetry() async {
        let fixture = SearchViewModelFixture()
        let load = Task { await fixture.viewModel.loadInitial() }
        await fixture.repository.waitUntilRequested()
        await fixture.repository.fail(.networkUnavailable)
        await load.value
        #expect(fixture.failure == .connection)
        let retry = Task { await fixture.viewModel.retrySearch() }
        await fixture.repository.waitUntilRequested(count: 2)
        #expect(fixture.isLoading)
        await fixture.repository.succeed(ids: [1], at: 1)
        await retry.value
        #expect(fixture.ids == [1])
    }

    @Test
    func debounceCancelsPreviousInputAndNormalizesWhitespaceAndCase() async throws {
        let debounce = ControlledDebounce()
        let fixture = SearchViewModelFixture(debounce: { await debounce.wait() })
        fixture.viewModel.updateSearchText("Rick")
        let first = try #require(fixture.viewModel.operation)
        await debounce.waitUntilRequested()
        #expect(await fixture.repository.requests.isEmpty)
        fixture.viewModel.updateSearchText("  Morty Smith\n")
        let second = try #require(fixture.viewModel.operation)
        #expect(first.isCancelled)
        await debounce.waitUntilRequested(count: 2)
        fixture.viewModel.updateSearchText(" MORTY SMITH ")
        #expect(fixture.viewModel.searchText == " MORTY SMITH ")
        #expect(fixture.viewModel.operation == second)
        #expect(!second.isCancelled)
        await debounce.release()
        await first.value
        #expect(await fixture.repository.requests.isEmpty)
        await debounce.release(1)
        await fixture.repository.waitUntilRequested()
        #expect(await fixture.repository.requests.first?.query == "morty smith")
        await fixture.repository.succeed(ids: [2])
        await second.value
        #expect(fixture.ids == [2])
        fixture.viewModel.updateSearchText("  MORTY SMITH ")
        #expect(fixture.ids == [2])
        #expect(await fixture.repository.requests.count == 1)
    }

    @Test(arguments: [false, true], [false, true])
    func obsoleteSearchCannotChangeNewQueryState(olderFails: Bool, olderFinishesFirst: Bool) async throws {
        var announcements: [String] = []
        let fixture = SearchViewModelFixture(announce: { announcements.append($0) })
        fixture.viewModel.updateSearchText("Rick")
        let old = try #require(fixture.viewModel.operation)
        await fixture.repository.waitUntilRequested()
        fixture.viewModel.updateSearchText("Morty")
        let new = try #require(fixture.viewModel.operation)
        #expect(old.isCancelled)
        #expect(fixture.ids == nil)
        #expect(fixture.isLoading)
        await fixture.repository.waitUntilRequested(count: 2)
        if !olderFinishesFirst {
            await fixture.repository.succeed(ids: [2], at: 1)
            await new.value
        }
        if olderFails {
            await fixture.repository.fail(.serviceFailure)
        } else {
            await fixture.repository.succeed(ids: [1], nextPage: 3)
        }
        await old.value
        if olderFinishesFirst {
            #expect(fixture.isLoading)
            #expect(fixture.failure == nil)
            await fixture.repository.succeed(ids: [2], at: 1)
            await new.value
        }
        #expect(fixture.ids == [2])
        #expect(fixture.viewModel.nextPage == nil)
        #expect(fixture.failure == nil)
        #expect(announcements == ["1 character found."])
    }

    @Test
    func queryChangeClearsLoadedResultsBeforeDebounceAndResetsToPageOne() async throws {
        let debounce = ControlledDebounce()
        let fixture = SearchViewModelFixture(debounce: { await debounce.wait() })
        await fixture.load(ids: [1], nextPage: 5)
        fixture.viewModel.updateSearchText("Morty")
        let search = try #require(fixture.viewModel.operation)
        #expect(fixture.ids == nil)
        #expect(fixture.viewModel.nextPage == nil)
        await fixture.viewModel.loadNextPage(approaching: 1)
        #expect(await fixture.repository.requests.count == 1)
        await debounce.waitUntilRequested()
        await debounce.release()
        await fixture.repository.waitUntilRequested(count: 2)
        #expect(await fixture.repository.requests.last == .init(query: "morty", page: 1))
        await fixture.repository.succeed(ids: [], at: 1)
        await search.value
        #expect(fixture.ids == [])
    }

    @Test
    func lifecycleCancellationReachesRepositoryAndAllowsReload() async {
        var announcements: [String] = []
        let fixture = SearchViewModelFixture(announce: { announcements.append($0) })
        let load = Task { await fixture.viewModel.loadInitial() }
        await fixture.repository.waitUntilRequested()
        load.cancel()
        await fixture.repository.succeed(ids: [1])
        await load.value
        #expect(await fixture.repository.cancelledRequests == [0])
        #expect(announcements.isEmpty)
        #expect(fixture.ids == nil)
        #expect(fixture.failure == nil)
        let retry = Task { await fixture.viewModel.loadInitial() }
        await fixture.repository.waitUntilRequested(count: 2)
        await fixture.repository.succeed(ids: [2], at: 1)
        await retry.value
        #expect(fixture.ids == [2])
    }

    @Test
    func announcesAcceptedSearchAndEmptyResultsButNotPagination() async throws {
        var announcements: [String] = []
        let fixture = SearchViewModelFixture(announce: { announcements.append($0) })
        await fixture.load(ids: [1, 2], nextPage: 2)
        #expect(announcements == ["2 characters found."])

        let pagination = Task { await fixture.viewModel.loadNextPage(approaching: 2) }
        await fixture.repository.waitUntilRequested(count: 2)
        await fixture.repository.succeed(ids: [3], at: 1)
        await pagination.value
        #expect(announcements == ["2 characters found."])

        fixture.viewModel.updateSearchText("No match")
        let search = try #require(fixture.viewModel.operation)
        await fixture.repository.waitUntilRequested(count: 3)
        await fixture.repository.succeed(ids: [], at: 2)
        await search.value
        #expect(announcements == ["2 characters found.", "No characters found."])
        #expect(fixture.viewModel.state == .loaded([]))
    }
}
