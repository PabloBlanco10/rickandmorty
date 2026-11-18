@testable import Data
import Foundation

/// Deliberately ignores cancellation until the test explicitly completes the request.
actor ControlledHTTPTransport: HTTPTransport {
    private var pending: CheckedContinuation<(Foundation.Data, URLResponse), any Error>?
    private var startedWaiters: [CheckedContinuation<Void, Never>] = []

    func data(for _: URLRequest) async throws -> (Foundation.Data, URLResponse) {
        try await withCheckedThrowingContinuation { continuation in
            precondition(pending == nil, "This transport controls one request per test")
            pending = continuation
            let waiters = startedWaiters
            startedWaiters.removeAll()
            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    func waitUntilRequested() async {
        if pending != nil {
            return
        }
        await withCheckedContinuation { startedWaiters.append($0) }
    }

    func succeed(data: Foundation.Data, response: URLResponse) {
        guard let continuation = pending else {
            preconditionFailure("Wait for the request before completing it")
        }
        pending = nil
        continuation.resume(returning: (data, response))
    }
}
