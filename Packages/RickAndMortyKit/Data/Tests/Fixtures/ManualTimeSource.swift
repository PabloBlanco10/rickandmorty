/// Frozen monotonic time, with an optional suspension to exercise cache reentrancy.
actor ManualTimeSource {
    private var instant = ContinuousClock().now
    private var suspendNext = false
    private var suspendedRead: CheckedContinuation<ContinuousClock.Instant, Never>?
    private var readWaiter: CheckedContinuation<Void, Never>?

    func now() async -> ContinuousClock.Instant {
        guard suspendNext else { return instant }
        suspendNext = false
        return await withCheckedContinuation { continuation in
            suspendedRead = continuation
            readWaiter?.resume()
            readWaiter = nil
        }
    }

    func advance(by duration: Duration) {
        instant = instant.advanced(by: duration)
    }

    func suspendNextRead() {
        precondition(suspendedRead == nil)
        suspendNext = true
    }

    func waitUntilReadSuspends() async {
        if suspendedRead != nil {
            return
        }
        precondition(readWaiter == nil)
        await withCheckedContinuation { readWaiter = $0 }
    }

    func resumeRead() {
        guard let continuation = suspendedRead else {
            preconditionFailure("Wait for the clock read before resuming it")
        }
        suspendedRead = nil
        continuation.resume(returning: instant)
    }
}
