@testable import Data
import Domain
import Foundation

struct SearchRepositoryFixture: Sendable {
    let time: ManualTimeSource
    let cache: MemoryCache<SearchCacheKey, CharacterPage>
    let repository: RickAndMortyCharacterRepository

    init(
        transport: any HTTPTransport,
        base: String = "https://example.com/api",
        ttl: Duration = .seconds(180)
    ) throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<SearchCacheKey, CharacterPage>(ttl: ttl, now: { time.now() })
        self.time = time
        self.cache = cache
        repository = try RickAndMortyCharacterRepository(
            baseURL: APIResponseFixture.url(base), client: HTTPClient(transport: transport), cache: cache
        )
    }

    static func page(id: Int = 1) throws -> CharacterPage {
        try JSONDecoder().decode(
            CharacterPageDTO.self, from: APIResponseFixture.pageData(next: nil, id: id)
        ).toDomain(requestedPage: 1)
    }
}
