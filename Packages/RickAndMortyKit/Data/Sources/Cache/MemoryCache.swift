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
    private let now: @Sendable () -> ContinuousClock.Instant
    private var entries: [Key: Entry] = [:]
    private var writes: [Key: UUID] = [:]

    /// A nonpositive TTL makes inserted values immediately expired.
    init(
        ttl: Duration = .seconds(180),
        now: @escaping @Sendable () -> ContinuousClock.Instant = { ContinuousClock().now }
    ) {
        self.ttl = ttl
        self.now = now
    }

    func value(for key: Key) -> Value? {
        let instant = now()
        guard let entry = entries[key] else { return nil }
        guard instant < entry.expiresAt else {
            entries.removeValue(forKey: key)
            return nil
        }
        return entry.value
    }

    func beginWrite(for key: Key) throws -> WriteToken {
        try Task.checkCancellation()
        let token = WriteToken(key: key, generation: UUID())
        writes[key] = token.generation
        return token
    }

    /// Returns false for superseded/finished writes. Token validation and insertion
    /// are atomic within the cache actor, with no suspension points.
    func commit(
        _ value: Value,
        using token: WriteToken
    ) throws -> Bool {
        let instant = now()
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
