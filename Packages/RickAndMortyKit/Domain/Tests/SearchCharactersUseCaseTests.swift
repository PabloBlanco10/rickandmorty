import Domain
import Foundation
import Testing

struct SearchCharactersUseCaseTests {
    @Test(arguments: [FetchPolicy.cacheFirst, .reloadIgnoringCache])
    func delegatesParametersAndReturnsCompletePage(policy: FetchPolicy) async throws {
        let character = try Character(
            id: 1,
            name: "Rick Sanchez",
            imageURL: #require(URL(string: "https://example.com/1.jpeg")),
            status: .alive,
            species: "Human",
            gender: .male,
            origin: "Earth",
            location: "Citadel"
        )
        let expected = CharacterPage(characters: [character], nextPage: 3)
        let repository = RepositorySpy(result: .success(expected))
        let useCase = SearchCharactersUseCase(repository: repository)

        let result = try await useCase.execute(query: " Rick ", page: 2, policy: policy)

        #expect(result == expected)
        #expect(await repository.requests == [Request(query: " Rick ", page: 2, policy: policy)])
    }

    @Test
    func defaultsToCacheFirstAndPreservesEmptyQuery() async throws {
        let expected = CharacterPage(characters: [], nextPage: nil)
        let repository = RepositorySpy(result: .success(expected))
        let useCase = SearchCharactersUseCase(repository: repository)

        let result = try await useCase.execute(query: "", page: 1)

        #expect(result == expected)
        #expect(await repository.requests == [Request(query: "", page: 1, policy: .cacheFirst)])
    }

    @Test
    func propagatesRepositoryError() async {
        let repository = RepositorySpy(result: .failure(RepositoryError.unavailable))
        let useCase = SearchCharactersUseCase(repository: repository)

        await #expect(throws: RepositoryError.unavailable) {
            try await useCase.execute(query: "Morty", page: 1)
        }
        #expect(await repository.requests == [Request(query: "Morty", page: 1, policy: .cacheFirst)])
    }

    @Test
    func propagatesCancellation() async {
        let repository = RepositorySpy(result: .failure(CancellationError()))
        let useCase = SearchCharactersUseCase(repository: repository)

        await #expect(throws: CancellationError.self) {
            try await useCase.execute(query: "Rick", page: 1)
        }
        #expect(await repository.requests.count == 1)
    }
}

private struct Request: Equatable, Sendable {
    let query: String
    let page: Int
    let policy: FetchPolicy
}

private enum RepositoryError: Error {
    case unavailable
}

private actor RepositorySpy: CharacterRepository {
    private let result: Result<CharacterPage, any Error>
    private(set) var requests: [Request] = []

    init(result: Result<CharacterPage, any Error>) {
        self.result = result
    }

    func searchCharacters(query: String, page: Int, policy: FetchPolicy) async throws -> CharacterPage {
        requests.append(Request(query: query, page: page, policy: policy))
        return try result.get()
    }
}
