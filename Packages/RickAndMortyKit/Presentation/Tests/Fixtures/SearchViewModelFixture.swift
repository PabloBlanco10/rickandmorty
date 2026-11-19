import Domain
@testable import Presentation

@MainActor
struct SearchViewModelFixture {
    let repository = ControlledCharacterRepository()
    let model: CharactersViewModel

    init(debounce: @escaping @Sendable () async throws -> Void = {}) {
        model = CharactersViewModel(useCase: SearchCharactersUseCase(repository: repository), debounce: debounce)
    }

    func load(ids: [Int] = [1], nextPage: Int? = 2) async {
        let task = Task { await model.loadInitial() }
        await repository.waitUntilRequested()
        await repository.succeed(ids: ids, nextPage: nextPage)
        await task.value
    }

    var ids: [Int]? {
        guard case let .loaded(characters) = model.state else { return nil }
        return characters.map(\.id)
    }

    var failure: CharactersError? {
        guard case let .failed(error) = model.state else { return nil }
        return error as? CharactersError
    }

    var isLoading: Bool {
        if case .loading = model.state {
            return true
        }
        return false
    }
}
