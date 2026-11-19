/// Tests release debounce explicitly; no wall-clock delays or scheduler polling.
actor ControlledDebounce {
    private var calls = 0
    private var pending: [Int: CheckedContinuation<Void, Never>] = [:]
    private var waiter: (count: Int, continuation: CheckedContinuation<Void, Never>)?

    func wait() async {
        let index = calls
        calls += 1
        await withCheckedContinuation { continuation in
            pending[index] = continuation
            if let waiter, calls >= waiter.count {
                self.waiter = nil
                waiter.continuation.resume()
            }
        }
    }

    func waitUntilRequested(count: Int = 1) async {
        guard calls < count else { return }
        precondition(waiter == nil)
        await withCheckedContinuation { waiter = (count, $0) }
    }

    func release(_ index: Int = 0) {
        guard let continuation = pending.removeValue(forKey: index) else {
            preconditionFailure("Wait for debounce before releasing it")
        }
        continuation.resume()
    }
}
