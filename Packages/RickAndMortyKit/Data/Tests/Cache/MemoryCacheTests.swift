@testable import Data
import Domain
import Foundation
import Testing

struct MemoryCacheTests {
    @Test
    func retrievesInsertedValueAndMissesUnknownKey() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<String, Int>(now: { await time.now() })
        #expect(await cache.value(for: "missing") == nil)
        try await cache.insert(42, for: "answer")
        #expect(await cache.value(for: "answer") == 42)
    }

    @Test
    func expiresExactlyAtDefaultTTLBoundary() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<String, Int>(now: { await time.now() })
        try await cache.insert(1, for: "key")
        await time.advance(by: .seconds(180) - .nanoseconds(1))
        #expect(await cache.value(for: "key") == 1)
        await time.advance(by: .nanoseconds(1))
        #expect(await cache.value(for: "key") == nil)
        #expect(await cache.value(for: "key") == nil)
    }

    @Test
    func honorsConfiguredTTL() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(ttl: .seconds(5), now: { await time.now() })
        try await cache.insert("value", for: 1)
        await time.advance(by: .seconds(5))
        #expect(await cache.value(for: 1) == nil)
    }

    @Test(arguments: [Duration.zero, .seconds(-1)])
    func nonpositiveTTLExpiresImmediately(ttl: Duration) async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, Int>(ttl: ttl, now: { await time.now() })
        try await cache.insert(1, for: 1)
        #expect(await cache.value(for: 1) == nil)
    }

    @Test
    func replacementRestartsTTL() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(ttl: .seconds(10), now: { await time.now() })
        try await cache.insert("old", for: 1)
        await time.advance(by: .seconds(9))
        try await cache.insert("new", for: 1)
        await time.advance(by: .seconds(1))
        #expect(await cache.value(for: 1) == "new")
        await time.advance(by: .seconds(9))
        #expect(await cache.value(for: 1) == nil)
    }

    @Test
    func removalKeepsOtherKeysIndependent() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(now: { await time.now() })
        try await cache.insert("one", for: 1)
        try await cache.insert("two", for: 2)
        await cache.removeValue(for: 1)
        #expect(await cache.value(for: 1) == nil)
        #expect(await cache.value(for: 2) == "two")
    }

    @Test
    func storesCharacterDetailsByIntegerIDWithoutADetailEndpoint() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, Domain.Character>(now: { await time.now() })
        let character = try Domain.Character(
            id: 1, name: "Rick", imageURL: APIResponseFixture.url("https://example.com/1.jpeg"),
            status: .alive, species: "Human", gender: .male, origin: "Earth", location: "Citadel"
        )
        try await cache.insert(character, for: character.id)
        #expect(await cache.value(for: 1) == character)
        #expect(await cache.value(for: 2) == nil)
    }

    @Test
    func rejectsOlderGenerationAfterNewerCommit() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(now: { await time.now() })
        let older = try await cache.beginWrite(for: 1)
        let newer = try await cache.beginWrite(for: 1)
        #expect(try await cache.commit("new", using: newer))
        #expect(try await !cache.commit("old", using: older))
        #expect(await cache.value(for: 1) == "new")
    }

    @Test
    func staleCleanupDoesNotRevokeNewerGeneration() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(now: { await time.now() })
        let older = try await cache.beginWrite(for: 1)
        let newer = try await cache.beginWrite(for: 1)
        await cache.finishWrite(older)
        #expect(try await cache.commit("new", using: newer))
        #expect(try await !cache.commit("old", using: older))
    }

    @Test
    func explicitRemovalRevokesPendingWrite() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(now: { await time.now() })
        let token = try await cache.beginWrite(for: 1)
        await cache.removeValue(for: 1)
        #expect(try await !cache.commit("late", using: token))
        #expect(await cache.value(for: 1) == nil)
    }

    @Test
    func directInsertionRevokesPendingWrite() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(now: { await time.now() })
        let token = try await cache.beginWrite(for: 1)
        try await cache.insert("replacement", for: 1)
        #expect(try await !cache.commit("late", using: token))
        #expect(await cache.value(for: 1) == "replacement")
    }

    @Test
    func rechecksGenerationAfterClockSuspension() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(now: { await time.now() })
        let older = try await cache.beginWrite(for: 1)
        await time.suspendNextRead()
        let oldCommit = Task { try await cache.commit("old", using: older) }
        await time.waitUntilReadSuspends()

        let newer = try await cache.beginWrite(for: 1)
        #expect(try await cache.commit("new", using: newer))
        await time.resumeRead()

        #expect(try await !oldCommit.value)
        #expect(await cache.value(for: 1) == "new")
    }

    @Test
    func cancellationDuringClockSuspensionPreservesValueAndExpiration() async throws {
        let time = ManualTimeSource()
        let cache = MemoryCache<Int, String>(now: { await time.now() })
        try await cache.insert("keep", for: 1)
        await time.advance(by: .seconds(179))
        let token = try await cache.beginWrite(for: 1)
        await time.suspendNextRead()
        let commit = Task { try await cache.commit("cancelled", using: token) }
        await time.waitUntilReadSuspends()
        commit.cancel()
        await time.resumeRead()

        await #expect(throws: CancellationError.self) { try await commit.value }
        await cache.finishWrite(token)
        #expect(await cache.value(for: 1) == "keep")
        await time.advance(by: .seconds(1))
        #expect(await cache.value(for: 1) == nil)
    }
}
