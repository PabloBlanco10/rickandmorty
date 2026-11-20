public struct GetCharacterDetailUseCase: Sendable {
    private let repository: any CharacterRepository

    public init(repository: any CharacterRepository) {
        self.repository = repository
    }

    public func execute(id: Int, policy: FetchPolicy = .cacheFirst) async throws -> Character {
        try await repository.character(id: id, policy: policy)
    }
}
