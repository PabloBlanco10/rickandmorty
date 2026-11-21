public protocol CharacterRepository: Sendable {
    /// Searches a one-based page. An empty query requests the general character list.
    func searchCharacters(
        query: String,
        page: Int,
        policy: FetchPolicy
    ) async throws -> CharacterPage
}
