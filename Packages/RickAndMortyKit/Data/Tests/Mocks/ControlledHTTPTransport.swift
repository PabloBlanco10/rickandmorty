@testable import Data
import Foundation

/// Records request order; each test explicitly completes its own requests.
/// Deliberately ignores cancellation to exercise late-response handling.
actor ControlledHTTPTransport: HTTPTransport {
    private var pending: [Int: CheckedContinuation<(Foundation.Data, URLResponse), any Error>] = [:]
    private var startedWaiters: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
    private(set) var requests: [URLRequest] = []

    func data(for request: URLRequest) async throws -> (Foundation.Data, URLResponse) {
        let index = requests.count
        requests.append(request)
        return try await withCheckedThrowingContinuation { continuation in
            pending[index] = continuation
            let ready = startedWaiters.filter { $0.count <= requests.count }
            startedWaiters.removeAll { $0.count <= requests.count }
            for waiter in ready {
                waiter.continuation.resume()
            }
        }
    }

    func waitUntilRequested(count: Int = 1) async {
        if requests.count >= count {
            return
        }
        await withCheckedContinuation { startedWaiters.append((count, $0)) }
    }

    func succeed(data: Foundation.Data, response: URLResponse, at index: Int = 0) {
        continuation(at: index).resume(returning: (data, response))
    }

    func fail(with error: any Error, at index: Int = 0) {
        continuation(at: index).resume(throwing: error)
    }

    private func continuation(at index: Int) -> CheckedContinuation<(Foundation.Data, URLResponse), any Error> {
        guard let continuation = pending.removeValue(forKey: index) else {
            preconditionFailure("Wait for the request and complete it only once")
        }
        return continuation
    }
}
