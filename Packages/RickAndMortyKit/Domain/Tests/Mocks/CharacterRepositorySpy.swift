import Domain

actor CharacterRepositorySpy: CharacterRepository {
    struct Request: Equatable, Sendable {
        let query: String
        let page: Int
    }

    private let result: Result<CharacterPage, any Error>
    private(set) var requests: [Request] = []

    init(result: Result<CharacterPage, any Error>) {
        self.result = result
    }

    func searchCharacters(query: String, page: Int) async throws -> CharacterPage {
        requests.append(Request(query: query, page: page))
        return try result.get()
    }
}
