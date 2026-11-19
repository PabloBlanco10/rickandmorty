import Domain
@testable import Presentation
import Testing

@MainActor
struct CharactersViewModelTests {
    @Test
    func initialLoadRequestsGeneralListOnce() async {
        let fixture = SearchViewModelFixture()
        let load = Task { await fixture.model.loadInitial() }
        await fixture.repository.waitUntilRequested()
        #expect(fixture.isLoading)
        #expect(await fixture.repository.requests == [.init(query: "", page: 1, policy: .cacheFirst)])
        await fixture.repository.succeed(ids: [1, 2], nextPage: 2)
        await load.value
        #expect(fixture.ids == [1, 2])
        #expect(fixture.model.nextPage == 2)
        await fixture.model.loadInitial()
        #expect(await fixture.repository.requests.count == 1)
    }

    @Test
    func emptyResultsAreLoadedWithoutError() async {
        let fixture = SearchViewModelFixture()
        await fixture.load(ids: [], nextPage: nil)
        #expect(fixture.ids == [])
        #expect(fixture.failure == nil)
        #expect(fixture.model.nextPage == nil)
    }

    @Test
    func searchFailureHasAnImmediateRetry() async {
        let fixture = SearchViewModelFixture()
        let load = Task { await fixture.model.loadInitial() }
        await fixture.repository.waitUntilRequested()
        await fixture.repository.fail(.networkUnavailable)
        await load.value
        #expect(fixture.failure == .connection)
        let retry = Task { await fixture.model.retrySearch() }
        await fixture.repository.waitUntilRequested(count: 2)
        #expect(fixture.isLoading)
        await fixture.repository.succeed(ids: [1], at: 1)
        await retry.value
        #expect(fixture.ids == [1])
        #expect(await fixture.repository.requests.last?.policy == .cacheFirst)
    }

    @Test
    func debounceCancelsPreviousInputAndNormalizesOnlySurroundingWhitespace() async throws {
        let debounce = ControlledDebounce()
        let fixture = SearchViewModelFixture(debounce: { await debounce.wait() })
        let first = try #require(fixture.model.updateSearchText("Rick"))
        await debounce.waitUntilRequested()
        #expect(await fixture.repository.requests.isEmpty)
        let second = try #require(fixture.model.updateSearchText("  Morty Smith\n"))
        #expect(first.isCancelled)
        await debounce.waitUntilRequested(count: 2)
        await debounce.release()
        await first.value
        #expect(await fixture.repository.requests.isEmpty)
        await debounce.release(1)
        await fixture.repository.waitUntilRequested()
        #expect(await fixture.repository.requests.first?.query == "Morty Smith")
        await fixture.repository.succeed(ids: [2])
        await second.value
        #expect(fixture.ids == [2])
        #expect(fixture.model.updateSearchText("Morty Smith") == nil)
        #expect(await fixture.repository.requests.count == 1)
    }

    @Test(arguments: [false, true], [false, true])
    func obsoleteSearchCannotChangeNewQueryState(olderFails: Bool, olderFinishesFirst: Bool) async throws {
        let fixture = SearchViewModelFixture()
        let old = try #require(fixture.model.updateSearchText("Rick"))
        await fixture.repository.waitUntilRequested()
        let new = try #require(fixture.model.updateSearchText("Morty"))
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
        #expect(fixture.model.nextPage == nil)
        #expect(fixture.failure == nil)
    }

    @Test
    func queryChangeClearsLoadedResultsBeforeDebounceAndResetsToPageOne() async throws {
        let debounce = ControlledDebounce()
        let fixture = SearchViewModelFixture(debounce: { await debounce.wait() })
        await fixture.load(ids: [1], nextPage: 5)
        let search = try #require(fixture.model.updateSearchText("Morty"))
        #expect(fixture.ids == nil)
        #expect(fixture.model.nextPage == nil)
        await debounce.waitUntilRequested()
        await debounce.release()
        await fixture.repository.waitUntilRequested(count: 2)
        #expect(await fixture.repository.requests.last == .init(query: "Morty", page: 1, policy: .cacheFirst))
        await fixture.repository.succeed(ids: [], at: 1)
        await search.value
        #expect(fixture.ids == [])
    }

    @Test
    func lifecycleCancellationReachesRepositoryAndAllowsReload() async {
        let fixture = SearchViewModelFixture()
        let load = Task { await fixture.model.loadInitial() }
        await fixture.repository.waitUntilRequested()
        load.cancel()
        await fixture.repository.succeed(ids: [1])
        await load.value
        #expect(await fixture.repository.cancelledRequests == [0])
        #expect(fixture.ids == nil)
        #expect(fixture.failure == nil)
        let retry = Task { await fixture.model.loadInitial() }
        await fixture.repository.waitUntilRequested(count: 2)
        await fixture.repository.succeed(ids: [2], at: 1)
        await retry.value
        #expect(fixture.ids == [2])
    }
}
