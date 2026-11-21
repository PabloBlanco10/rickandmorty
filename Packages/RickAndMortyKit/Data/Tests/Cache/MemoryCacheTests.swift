@testable import Data
import Domain
import Foundation
import Testing

struct MemoryCacheTests {
    @Test
    func retrievesCommittedValueAndMissesUnknownKey() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<String, Int>(now: { time.now() })
        #expect(await cache.value(for: "missing") == nil)
        try await cache.seed(42, for: "answer")
        #expect(await cache.value(for: "answer") == 42)
    }

    @Test
    func expiresExactlyAtDefaultTTLBoundary() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<String, Int>(now: { time.now() })
        try await cache.seed(1, for: "key")
        time.advance(by: .seconds(180) - .nanoseconds(1))
        #expect(await cache.value(for: "key") == 1)
        time.advance(by: .nanoseconds(1))
        #expect(await cache.value(for: "key") == nil)
        #expect(await cache.value(for: "key") == nil)
    }

    @Test
    func honorsConfiguredTTL() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(ttl: .seconds(5), now: { time.now() })
        try await cache.seed("value", for: 1)
        time.advance(by: .seconds(5))
        #expect(await cache.value(for: 1) == nil)
    }

    @Test(arguments: [Duration.zero, .seconds(-1)])
    func nonpositiveTTLExpiresImmediately(ttl: Duration) async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, Int>(ttl: ttl, now: { time.now() })
        try await cache.seed(1, for: 1)
        #expect(await cache.value(for: 1) == nil)
    }

    @Test
    func replacementRestartsTTL() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(ttl: .seconds(10), now: { time.now() })
        try await cache.seed("old", for: 1)
        time.advance(by: .seconds(9))
        try await cache.seed("new", for: 1)
        time.advance(by: .seconds(1))
        #expect(await cache.value(for: 1) == "new")
        time.advance(by: .seconds(9))
        #expect(await cache.value(for: 1) == nil)
    }

    @Test
    func storesCharacterValuesByIntegerKey() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, Domain.Character>(now: { time.now() })
        let character = try Domain.Character(
            id: 1, name: "Rick", imageURL: APIResponseFixture.url("https://example.com/1.jpeg"),
            status: .alive, species: "Human", gender: .male, origin: "Earth", location: "Citadel"
        )
        try await cache.seed(character, for: character.id)
        #expect(await cache.value(for: 1) == character)
        #expect(await cache.value(for: 2) == nil)
    }

    @Test
    func rejectsOlderGenerationAfterNewerCommit() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(now: { time.now() })
        let older = try await cache.beginWrite(for: 1)
        let newer = try await cache.beginWrite(for: 1)
        #expect(try await cache.commit("new", using: newer))
        #expect(try await !cache.commit("old", using: older))
        #expect(await cache.value(for: 1) == "new")
    }

    @Test
    func staleCleanupDoesNotRevokeNewerGeneration() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(now: { time.now() })
        let older = try await cache.beginWrite(for: 1)
        let newer = try await cache.beginWrite(for: 1)
        await cache.finishWrite(older)
        #expect(try await cache.commit("new", using: newer))
        #expect(try await !cache.commit("old", using: older))
    }

    @Test
    func cancelledCommitPreservesValueAndExpiration() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(now: { time.now() })
        try await cache.seed("keep", for: 1)
        time.advance(by: .seconds(179))
        let token = try await cache.beginWrite(for: 1)
        let commit = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await cache.commit("cancelled", using: token)
        }
        await #expect(throws: CancellationError.self) { try await commit.value }
        await cache.finishWrite(token)
        #expect(await cache.value(for: 1) == "keep")
        time.advance(by: .seconds(1))
        #expect(await cache.value(for: 1) == nil)
    }
}
