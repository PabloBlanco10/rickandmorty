public struct SearchCharactersUseCase: Sendable {
    private let repository: any CharacterRepository

    public init(repository: any CharacterRepository) {
        self.repository = repository
    }

    public func execute(
        query: String,
        page: Int,
        policy: FetchPolicy = .cacheFirst
    ) async throws -> CharacterPage {
        try await repository.searchCharacters(query: query, page: page, policy: policy)
    }
}
