import Domain
import Testing

private enum RepositoryError: Error {
    case unavailable
}

struct SearchCharactersUseCaseTests {
    @Test(arguments: [
        ("  Rick\n", "rick"), ("rICK", "rick"),
        (" MORTY Smith ", "morty smith"), (" \n", "")
    ])
    func executeNormalizesEquivalentQueries(input: String, expected: String) async throws {
        let repository = CharacterRepositorySpy(result: .success(CharacterPage(characters: [], nextPage: nil)))
        let useCase = SearchCharactersUseCase(repository: repository)

        _ = try await useCase.execute(query: input, page: 1)

        #expect(await repository.requests == [.init(query: expected, page: 1)])
    }

    @Test
    func delegatesParametersAndReturnsCompletePage() async throws {
        let character = try Domain.Character.fixture()
        let expected = CharacterPage(characters: [character], nextPage: 3)
        let repository = CharacterRepositorySpy(result: .success(expected))
        let useCase = SearchCharactersUseCase(repository: repository)

        let result = try await useCase.execute(query: " Rick ", page: 2)

        #expect(result == expected)
        #expect(await repository.requests == [CharacterRepositorySpy.Request(query: "rick", page: 2)])
    }

    @Test
    func preservesEmptyQuery() async throws {
        let expected = CharacterPage(characters: [], nextPage: nil)
        let repository = CharacterRepositorySpy(result: .success(expected))
        let useCase = SearchCharactersUseCase(repository: repository)

        let result = try await useCase.execute(query: "", page: 1)

        #expect(result == expected)
        #expect(await repository.requests == [CharacterRepositorySpy.Request(query: "", page: 1)])
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
            page: 1
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
