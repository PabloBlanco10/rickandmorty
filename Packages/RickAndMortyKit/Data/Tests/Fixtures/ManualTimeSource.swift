import os

/// Synchronous monotonic reads; the lock protects both reads and explicit advances.
final class ManualTimeSource: Sendable {
    private let instant = OSAllocatedUnfairLock(initialState: ContinuousClock().now)

    func now() -> ContinuousClock.Instant {
        instant.withLock { $0 }
    }

    func advance(by duration: Duration) {
        instant.withLock { $0 = $0.advanced(by: duration) }
    }
}
