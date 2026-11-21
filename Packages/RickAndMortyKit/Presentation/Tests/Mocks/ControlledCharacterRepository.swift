import Domain

/// Each test owns its requests and completions. Ignores cancellation deliberately.
actor ControlledCharacterRepository: CharacterRepository {
    struct Request: Equatable, Sendable {
        let query: String
        let page: Int
        let policy: FetchPolicy
    }

    private(set) var requests: [Request] = []
    private(set) var cancelledRequests: Set<Int> = []
    private var pending: [Int: CheckedContinuation<CharacterPage, any Error>] = [:]
    private var waiter: (count: Int, continuation: CheckedContinuation<Void, Never>)?

    func searchCharacters(query: String, page: Int, policy: FetchPolicy) async throws -> CharacterPage {
        let index = requests.count
        requests.append(Request(query: query, page: page, policy: policy))
        defer {
            if Task.isCancelled {
                cancelledRequests.insert(index)
            }
        }
        return try await withCheckedThrowingContinuation { continuation in
            pending[index] = continuation
            if let waiter, requests.count >= waiter.count {
                self.waiter = nil
                waiter.continuation.resume()
            }
        }
    }

    func waitUntilRequested(count: Int = 1) async {
        guard requests.count < count else {
            return
        }
        precondition(waiter == nil)
        await withCheckedContinuation { waiter = (count, $0) }
    }

    func succeed(ids: [Int], nextPage: Int? = nil, at index: Int = 0) {
        continuation(at: index).resume(returning: CharacterPage(
            characters: ids.map { .fixture(id: $0) },
            nextPage: nextPage
        ))
    }

    func fail(_ error: CharacterRepositoryError, at index: Int = 0) {
        continuation(at: index).resume(throwing: error)
    }

    private func continuation(at index: Int) -> CheckedContinuation<CharacterPage, any Error> {
        guard let continuation = pending.removeValue(forKey: index) else {
            preconditionFailure("Wait for each request and complete it exactly once")
        }
        return continuation
    }
}
