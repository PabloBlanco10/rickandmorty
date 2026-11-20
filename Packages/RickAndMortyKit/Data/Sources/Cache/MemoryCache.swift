import Foundation

/// Independent per-key storage and expiration; callers own fetching.
actor MemoryCache<Key: Hashable & Sendable, Value: Sendable> {
    struct WriteToken: Sendable {
        let key: Key
        let generation: UUID
    }

    private struct Entry {
        let value: Value
        let expiresAt: ContinuousClock.Instant
    }

    private let ttl: Duration
    private let now: @Sendable () async -> ContinuousClock.Instant
    private var entries: [Key: Entry] = [:]
    private var writes: [Key: UUID] = [:]

    /// A nonpositive TTL makes inserted values immediately expired.
    init(
        ttl: Duration = .seconds(180),
        now: @escaping @Sendable () async -> ContinuousClock.Instant = { ContinuousClock().now }
    ) {
        self.ttl = ttl
        self.now = now
    }

    func value(for key: Key) async -> Value? {
        let instant = await now()
        guard let entry = entries[key] else { return nil }
        guard instant < entry.expiresAt else {
            entries.removeValue(forKey: key)
            return nil
        }
        return entry.value
    }

    /// Explicit replacement restarts the TTL and supersedes pending writes for this key.
    func insert(_ value: Value, for key: Key) async throws {
        let instant = await now()
        try Task.checkCancellation()
        writes.removeValue(forKey: key)
        entries[key] = Entry(value: value, expiresAt: instant.advanced(by: ttl))
    }

    func removeValue(for key: Key) {
        entries.removeValue(forKey: key)
        writes.removeValue(forKey: key)
    }

    func beginWrite(for key: Key) throws -> WriteToken {
        try Task.checkCancellation()
        let token = WriteToken(key: key, generation: UUID())
        writes[key] = token.generation
        return token
    }

    /// Returns false for superseded/removed writes. Token validation and insertion
    /// are atomic after any suspension needed by the injected clock.
    func commit(
        _ value: Value,
        using token: WriteToken
    ) async throws -> Bool {
        let instant = await now()
        try Task.checkCancellation()
        guard writes[token.key] == token.generation else { return false }

        // Do not await between the token check and insertion.
        entries[token.key] = Entry(value: value, expiresAt: instant.advanced(by: ttl))
        writes.removeValue(forKey: token.key)
        return true
    }

    /// Cleanup must also work from a cancelled caller and must not revoke a newer token.
    func finishWrite(_ token: WriteToken) {
        if writes[token.key] == token.generation {
            writes.removeValue(forKey: token.key)
        }
    }
}
