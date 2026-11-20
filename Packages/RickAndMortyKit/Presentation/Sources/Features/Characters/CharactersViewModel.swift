import Domain
import Foundation
import Observation

@MainActor
@Observable
public final class CharactersViewModel {
    private(set) var searchText = ""
    private(set) var state: ViewState<[Character]>
    private(set) var nextPage: Int?
    private(set) var isLoadingNextPage = false
    private(set) var paginationError: CharactersError?

    @ObservationIgnored private let useCase: SearchCharactersUseCase
    @ObservationIgnored private let debounce: @Sendable () async throws -> Void
    // Read-only inside the module so tests can await exact completion after a Void UI action.
    @ObservationIgnored private(set) var operation: Task<Void, Never>?
    @ObservationIgnored private var generation = UUID()
    @ObservationIgnored private var query = ""

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

    var isInitialLoading: Bool {
        switch state {
        case .idle, .loading: true
        default: false
        }
    }

    func loadInitial() async {
        guard case .idle = state else {
            return
        }
        await wait(for: startLoading())
    }

    /// The binding calls this synchronously: obsolete work is invalidated before debounce.
    func updateSearchText(_ text: String) {
        searchText = text
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard normalized != query else {
            return
        }
        query = normalized
        _ = startLoading(debounced: true)
    }

    func retrySearch() async {
        await wait(for: startLoading())
    }

    func loadNextPage(approaching characterID: Int) async {
        guard case let .loaded(characters) = state,
              characters.suffix(3).contains(where: { $0.id == characterID })
        else {
            return
        }
        await loadNextPage()
    }

    private func loadNextPage() async {
        guard operation == nil,
              paginationError == nil,
              case .loaded = state,
              let nextPage
        else {
            return
        }
        await wait(for: startLoading(page: nextPage))
    }

    func retryPagination() async {
        guard operation == nil,
              paginationError != nil
        else {
            return
        }
        paginationError = nil
        await loadNextPage()
    }

    func cancel() {
        generation = UUID()
        operation?.cancel()
        operation = nil
        isLoadingNextPage = false
        if case .loading = state {
            state = .idle
        }
    }

    private func startLoading(
        page: Int = 1, debounced: Bool = false
    ) -> Task<Void, Never> {
        cancel()
        let token = generation
        let query = query
        paginationError = nil
        if page > 1 {
            isLoadingNextPage = true
        } else {
            state = .loading
            nextPage = nil
        }

        // UI events need an owned task. Capture dependencies rather than holding self
        // across a transport that may ignore cancellation.
        let task = Task { [weak self, useCase, debounce] in
            do {
                if debounced {
                    try await debounce()
                }
                try Task.checkCancellation()
                let result = try await useCase.execute(query: query, page: page, policy: .cacheFirst)
                try Task.checkCancellation()
                guard let self,
                      generation == token
                else {
                    return
                }
                accept(result, page: page)
            } catch {
                guard let self,
                      generation == token
                else {
                    return
                }
                if error is CancellationError || Task.isCancelled {
                    if case .loading = state {
                        state = .idle
                    }
                } else {
                    show(CharactersError(error), page: page)
                }
            }
            self?.finish(token)
        }
        operation = task
        return task
    }

    private func accept(_ result: CharacterPage, page: Int) {
        if page > 1,
           case let .loaded(existing) = state
        {
            var ids = Set(existing.map(\.id))
            state = .loaded(existing + result.characters.filter { ids.insert($0.id).inserted })
        } else {
            state = .loaded(result.characters)
        }
        nextPage = result.nextPage
    }

    private func show(_ error: CharactersError, page: Int) {
        if page > 1 {
            paginationError = error
        } else {
            state = .failed(error)
        }
    }

    private func finish(_ token: UUID) {
        guard generation == token else {
            return
        }
        operation = nil
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
