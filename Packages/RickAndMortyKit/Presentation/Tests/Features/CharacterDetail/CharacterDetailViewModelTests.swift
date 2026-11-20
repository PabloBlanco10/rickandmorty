import Domain
@testable import Presentation
import Testing

@MainActor
struct CharacterDetailViewModelTests {
    @Test
    func loadsOneCharacterAndPreventsDuplicateOrUnnecessaryLoads() async {
        let repository = ControlledCharacterRepository()
        let viewModel = CharacterDetailViewModel(id: 7, useCase: GetCharacterDetailUseCase(repository: repository))
        let load = Task { await viewModel.load() }
        await repository.waitForDetail()
        switch viewModel.state {
        case .loading:
            break
        default:
            Issue.record("Expected loading state")
        }
        await viewModel.load()
        #expect(await repository.detailRequests == [.init(id: 7, policy: .cacheFirst)])
        await repository.completeDetail(.success(.fixture(id: 7)))
        await load.value
        if case let .loaded(character) = viewModel.state {
            #expect(character == .fixture(id: 7))
        } else {
            Issue.record("Expected character data")
        }
        await viewModel.load()
        #expect(await repository.detailRequests.count == 1)
    }

    @Test
    func failureCanBeRetried() async {
        let repository = ControlledCharacterRepository()
        let viewModel = CharacterDetailViewModel(id: 1, useCase: GetCharacterDetailUseCase(repository: repository))
        let load = Task { await viewModel.load() }
        await repository.waitForDetail()
        await repository.completeDetail(.failure(CharacterRepositoryError.networkUnavailable))
        await load.value
        if case let .failed(error) = viewModel.state {
            #expect(error as? CharactersError == .connection)
        } else {
            Issue.record("Expected a retryable failure")
        }
        let retry = Task { await viewModel.load() }
        await repository.waitForDetail(count: 2)
        await repository.completeDetail(.success(.fixture(id: 1)), at: 1)
        await retry.value
        if case let .loaded(character) = viewModel.state {
            #expect(character.id == 1)
        } else {
            Issue.record("Expected retry to load the character")
        }
    }

    @Test
    func cancelledLateSuccessIsNotPublishedAndDoesNotShowError() async {
        let repository = ControlledCharacterRepository()
        let viewModel = CharacterDetailViewModel(id: 1, useCase: GetCharacterDetailUseCase(repository: repository))
        let load = Task { await viewModel.load() }
        await repository.waitForDetail()
        load.cancel()
        await repository.completeDetail(.success(.fixture(id: 1)))
        await load.value
        switch viewModel.state {
        case .idle:
            break
        default:
            Issue.record("Cancellation should return to idle")
        }
        let retry = Task { await viewModel.load() }
        await repository.waitForDetail(count: 2)
        await repository.completeDetail(.success(.fixture(id: 1)), at: 1)
        await retry.value
        switch viewModel.state {
        case .loaded:
            break
        default:
            Issue.record("Expected a new load after cancellation")
        }
    }

    @Test
    func alreadyCancelledTaskDoesNotStartRequest() async {
        let repository = ControlledCharacterRepository()
        let viewModel = CharacterDetailViewModel(id: 1, useCase: GetCharacterDetailUseCase(repository: repository))
        // This test holds MainActor until cancel(), so the child cannot start first.
        let load = Task { await viewModel.load() }
        load.cancel()
        await load.value
        #expect(await repository.detailRequests.isEmpty)
        switch viewModel.state {
        case .idle:
            break
        default:
            Issue.record("Expected idle state")
        }
    }
}
