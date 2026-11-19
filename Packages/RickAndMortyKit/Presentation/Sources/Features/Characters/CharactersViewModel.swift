import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class CharactersViewModel {
    private(set) var searchText = ""
    private(set) var state: ViewState<[Character]>
    private(set) var nextPage: Int?
    private(set) var isRefreshing = false
    private(set) var isLoadingNextPage = false
    private(set) var refreshError: CharactersError?
    private(set) var paginationError: CharactersError?

    @ObservationIgnored private let useCase: SearchCharactersUseCase
    @ObservationIgnored private let debounce: @Sendable () async throws -> Void
    @ObservationIgnored private var operation: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var query = ""

    private enum Request {
        case search, refresh, page(Int)

        var page: Int {
            if case let .page(number) = self {
                return number
            }
            return 1
        }

        var policy: FetchPolicy {
            if case .refresh = self {
                return .reloadIgnoringCache
            }
            return .cacheFirst
        }
    }

    public convenience init(useCase: SearchCharactersUseCase) {
        self.init(useCase: useCase, debounce: {
            try await ContinuousClock().sleep(for: .milliseconds(300))
        })
    }

    init(
        useCase: SearchCharactersUseCase,
        initialState: ViewState<[Character]> = .idle,
        debounce: @escaping @Sendable () async throws -> Void
    ) {
        self.useCase = useCase
        self.debounce = debounce
        state = initialState
    }

    func loadInitial() async {
        guard case .idle = state else { return }
        await wait(for: start(.search))
    }

    /// The binding calls this synchronously: obsolete work is invalidated before debounce.
    @discardableResult
    func updateSearchText(_ text: String) -> Task<Void, Never>? {
        searchText = text
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized != query else { return nil }
        query = normalized
        return start(.search, debounced: true)
    }

    func retrySearch() async {
        await wait(for: start(.search))
    }

    func loadNextPage() async {
        guard operation == nil, paginationError == nil,
              case .loaded = state, let nextPage else { return }
        await wait(for: start(.page(nextPage)))
    }

    func retryPagination() async {
        guard operation == nil, paginationError != nil else { return }
        paginationError = nil
        await loadNextPage()
    }

    func refresh() async {
        await wait(for: start(.refresh))
    }

    func cancel() {
        generation = UUID()
        operation?.cancel()
        operation = nil
        isRefreshing = false
        isLoadingNextPage = false
        if case .loading = state {
            state = .idle
        }
    }

    private func start(_ request: Request, debounced: Bool = false) -> Task<Void, Never> {
        cancel()
        let token = generation
        let query = query
        refreshError = nil
        paginationError = nil
        switch request {
        case .search:
            state = .loading
            nextPage = nil
        case .refresh:
            isRefreshing = true
            if case .loaded = state {} else {
                state = .loading
            }
        case .page:
            isLoadingNextPage = true
        }

        // UI events need an owned task. Capture dependencies rather than holding self
        // across a transport that may ignore cancellation.
        let task = Task { [weak self, useCase, debounce] in
            do {
                if debounced {
                    try await debounce()
                }
                try Task.checkCancellation()
                let page = try await useCase.execute(query: query, page: request.page, policy: request.policy)
                try Task.checkCancellation()
                guard let self, generation == token else { return }
                receive(page, for: request)
            } catch {
                guard let self, generation == token else { return }
                if error is CancellationError || Task.isCancelled {
                    if case .loading = state {
                        state = .idle
                    }
                } else {
                    receive(CharactersError(error), for: request)
                }
            }
            self?.finish(token)
        }
        operation = task
        return task
    }

    private func receive(_ page: CharacterPage, for request: Request) {
        if case .page = request, case let .loaded(existing) = state {
            var ids = Set(existing.map(\.id))
            state = .loaded(existing + page.characters.filter { ids.insert($0.id).inserted })
        } else {
            state = .loaded(page.characters)
        }
        nextPage = page.nextPage
    }

    private func receive(_ error: CharactersError, for request: Request) {
        switch request {
        case .search:
            state = .failed(error)
        case .refresh:
            if case .loaded = state {
                refreshError = error
            } else {
                state = .failed(error)
            }
        case .page:
            paginationError = error
        }
    }

    private func finish(_ token: UUID) {
        guard generation == token else { return }
        operation = nil
        isRefreshing = false
        isLoadingNextPage = false
    }

    private func wait(for task: Task<Void, Never>) async {
        // Awaiting an owned task alone does not forward SwiftUI lifecycle cancellation.
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }
    }
}
