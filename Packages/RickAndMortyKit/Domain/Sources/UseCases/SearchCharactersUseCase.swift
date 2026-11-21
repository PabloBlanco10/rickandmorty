import Foundation

public struct SearchCharactersUseCase: Sendable {
    private let repository: any CharacterRepository

    public init(repository: any CharacterRepository) {
        self.repository = repository
    }

    /// Shared query equivalence for UI cancellation, request parameters and cache keys.
    public static func normalizedQuery(_ query: String) -> String {
        query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    public func execute(
        query: String,
        page: Int,
        policy: FetchPolicy = .cacheFirst
    ) async throws -> CharacterPage {
        try await repository.searchCharacters(query: Self.normalizedQuery(query), page: page, policy: policy)
    }
}
