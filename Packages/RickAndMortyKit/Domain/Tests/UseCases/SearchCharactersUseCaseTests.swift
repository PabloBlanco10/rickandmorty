import Domain
import Foundation
import Testing

struct SearchCharactersUseCaseTests {
    @Test(arguments: [
        ("  Rick\n", "rick"), ("rICK", "rick"),
        (" MORTY Smith ", "morty smith"), (" \n", "")
    ])
    func executeNormalizesEquivalentQueries(input: String, expected: String) async throws {
        let repository = CharacterRepositorySpy(result: .success(CharacterPage(characters: [], nextPage: nil)))
        let useCase = SearchCharactersUseCase(repository: repository)

        _ = try await useCase.execute(query: input, page: 1)

        #expect(await repository.requests == [.init(query: expected, page: 1, policy: .cacheFirst)])
    }

    @Test(arguments: [FetchPolicy.cacheFirst, .reloadIgnoringCache])
    func delegatesParametersAndReturnsCompletePage(policy: FetchPolicy) async throws {
        let character = try Domain.Character.fixture()
        let expected = CharacterPage(characters: [character], nextPage: 3)
        let repository = CharacterRepositorySpy(result: .success(expected))
        let useCase = SearchCharactersUseCase(repository: repository)

        let result = try await useCase.execute(query: " Rick ", page: 2, policy: policy)

        #expect(result == expected)
        #expect(await repository.requests == [CharacterRepositorySpy.Request(query: "rick", page: 2, policy: policy)])
    }

    @Test
    func defaultsToCacheFirstAndPreservesEmptyQuery() async throws {
        let expected = CharacterPage(characters: [], nextPage: nil)
        let repository = CharacterRepositorySpy(result: .success(expected))
        let useCase = SearchCharactersUseCase(repository: repository)

        let result = try await useCase.execute(query: "", page: 1)

        #expect(result == expected)
        #expect(await repository.requests == [CharacterRepositorySpy.Request(query: "", page: 1, policy: .cacheFirst)])
    }

    @Test
    func propagatesRepositoryError() async {
        let repository = CharacterRepositorySpy(result: .failure(RepositoryError.unavailable))
        let useCase = SearchCharactersUseCase(repository: repository)

        await #expect(throws: RepositoryError.unavailable) {
            try await useCase.execute(query: "Morty", page: 1)
        }
        #expect(await repository.requests == [CharacterRepositorySpy.Request(
            query: "morty",
            page: 1,
            policy: .cacheFirst
        )])
    }

    @Test
    func propagatesCancellation() async {
        let repository = CharacterRepositorySpy(result: .failure(CancellationError()))
        let useCase = SearchCharactersUseCase(repository: repository)

        await #expect(throws: CancellationError.self) {
            try await useCase.execute(query: "Rick", page: 1)
        }
        #expect(await repository.requests.count == 1)
    }
}

private enum RepositoryError: Error {
    case unavailable
}
