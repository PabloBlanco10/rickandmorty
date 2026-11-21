import Domain

actor CharacterRepositorySpy: CharacterRepository {
    struct Request: Equatable, Sendable {
        let query: String
        let page: Int
        let policy: FetchPolicy
    }

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
