@testable import Data
import Foundation

actor HTTPTransportSpy: HTTPTransport {
    private let result: Result<(Foundation.Data, URLResponse), any Error>
    private(set) var requests: [URLRequest] = []

    init(data: Foundation.Data = Foundation.Data(), response: URLResponse) {
        result = .success((data, response))
    }

    init(error: any Error) {
        result = .failure(error)
    }

    func data(for request: URLRequest) async throws -> (Foundation.Data, URLResponse) {
        requests.append(request)
        return try result.get()
    }
}
