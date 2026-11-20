import Domain

actor CharacterRepositorySpy: CharacterRepository {
    struct Request: Equatable, Sendable {
        let query: String
        let page: Int
        let policy: FetchPolicy
    }

    struct DetailRequest: Equatable, Sendable {
        let id: Int
        let policy: FetchPolicy
    }

    private let detailResult: Result<Character, any Error>
    private(set) var detailRequests: [DetailRequest] = []
    private let result: Result<CharacterPage, any Error>
    private(set) var requests: [Request] = []

    init(result: Result<CharacterPage, any Error>) {
        self.result = result
        detailResult = .failure(CharacterRepositoryError.unexpected)
    }

    init(detailResult: Result<Character, any Error>) {
        self.detailResult = detailResult
        result = .failure(CharacterRepositoryError.unexpected)
    }

    func character(id: Int, policy: FetchPolicy) async throws -> Character {
        detailRequests.append(DetailRequest(id: id, policy: policy))
        return try detailResult.get()
    }

    func searchCharacters(query: String, page: Int, policy: FetchPolicy) async throws -> CharacterPage {
        requests.append(Request(query: query, page: page, policy: policy))
        return try result.get()
    }
}
