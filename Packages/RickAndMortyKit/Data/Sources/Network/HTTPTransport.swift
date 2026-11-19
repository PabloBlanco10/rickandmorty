import Foundation

protocol HTTPTransport: Sendable {
    func data(for request: URLRequest) async throws -> (Foundation.Data, URLResponse)
}

struct URLSessionTransport: HTTPTransport {
    let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.urlCache = nil
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    func data(for request: URLRequest) async throws -> (Foundation.Data, URLResponse) {
        try await session.data(for: request)
    }
}
