import Domain
import Testing

struct GetCharacterDetailUseCaseTests {
    @Test(arguments: [FetchPolicy.cacheFirst, .reloadIgnoringCache])
    func delegatesIDAndPolicyAndReturnsCharacter(policy: FetchPolicy) async throws {
        let expected = try Character.fixture()
        let repository = CharacterRepositorySpy(detailResult: .success(expected))
        let useCase = GetCharacterDetailUseCase(repository: repository)
        #expect(try await useCase.execute(id: expected.id, policy: policy) == expected)
        #expect(await repository.detailRequests == [.init(id: expected.id, policy: policy)])
    }

    @Test
    func defaultsToCacheFirst() async throws {
        let repository = try CharacterRepositorySpy(detailResult: .success(Character.fixture()))
        _ = try await GetCharacterDetailUseCase(repository: repository).execute(id: 1)
        #expect(await repository.detailRequests == [.init(id: 1, policy: .cacheFirst)])
    }

    @Test
    func propagatesFailure() async {
        let repository = CharacterRepositorySpy(detailResult: .failure(CharacterRepositoryError.serviceFailure))
        await #expect(throws: CharacterRepositoryError.serviceFailure) {
            try await GetCharacterDetailUseCase(repository: repository).execute(id: 1)
        }
    }

    @Test
    func propagatesCancellation() async {
        let repository = CharacterRepositorySpy(detailResult: .failure(CancellationError()))
        await #expect(throws: CancellationError.self) {
            try await GetCharacterDetailUseCase(repository: repository).execute(id: 1)
        }
    }
}
