import Domain
@testable import Presentation

@MainActor
struct SearchViewModelFixture {
    let repository = ControlledCharacterRepository()
    let viewModel: CharactersViewModel

    var ids: [Int]? {
        guard case let .loaded(characters) = viewModel.state else {
            return nil
        }
        return characters.map(\.id)
    }

    var failure: CharactersError? {
        guard case let .failed(error) = viewModel.state else {
            return nil
        }
        return error
    }

    var isLoading: Bool {
        if case .loading = viewModel.state {
            return true
        }
        return false
    }

    init(
        announce: @escaping @MainActor (String) -> Void = { _ in },
        debounce: @escaping @Sendable () async throws -> Void = {}
    ) {
        viewModel = CharactersViewModel(
            useCase: SearchCharactersUseCase(repository: repository), announce: announce, debounce: debounce
        )
    }

    func load(ids: [Int] = [1], nextPage: Int? = 2) async {
        let task = Task { await viewModel.loadInitial() }
        await repository.waitUntilRequested()
        await repository.succeed(ids: ids, nextPage: nextPage)
        await task.value
    }
}
