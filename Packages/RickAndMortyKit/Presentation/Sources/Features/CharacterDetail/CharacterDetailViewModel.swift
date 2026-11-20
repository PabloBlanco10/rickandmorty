import Domain
import Observation

@MainActor
@Observable
final class CharacterDetailViewModel {
    let id: Int
    private(set) var state: ViewState<Character> = .idle
    @ObservationIgnored private let useCase: GetCharacterDetailUseCase

    init(id: Int, useCase: GetCharacterDetailUseCase) {
        self.id = id
        self.useCase = useCase
    }

    /// One immutable ID per destination. SwiftUI owns and cancels the calling task.
    func load() async {
        guard !Task.isCancelled else {
            return
        }
        switch state {
        case .loading, .loaded:
            return
        case .idle, .failed:
            break
        }
        state = .loading
        do {
            let character = try await useCase.execute(id: id)
            try Task.checkCancellation()
            state = .loaded(character)
        } catch {
            if Task.isCancelled || error is CancellationError {
                state = .idle
            } else {
                state = .failed(CharactersError(error))
            }
        }
    }
}
