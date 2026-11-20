@testable import Data
import Domain

struct DetailRepositoryFixture: Sendable {
    let time: ManualTimeSource
    let cache: MemoryCache<Int, Character>
    let repository: RickAndMortyCharacterRepository

    init(transport: any HTTPTransport, ttl: Duration = .seconds(180), base: String = "https://example.com/api") throws {
        let time = ManualTimeSource()
        self.time = time
        cache = MemoryCache(ttl: ttl, now: { await time.now() })
        repository = try RickAndMortyCharacterRepository(
            baseURL: APIResponseFixture.url(base), client: HTTPClient(transport: transport),
            cache: MemoryCache(ttl: ttl, now: { await time.now() }), detailCache: cache
        )
    }
}
