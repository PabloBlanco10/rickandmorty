import Foundation

struct HTTPClient: Sendable {
    private let transport: any HTTPTransport

    init(transport: any HTTPTransport) {
        self.transport = transport
    }

    func get<Response: Decodable & Sendable>(from url: URL) async throws -> Response {
        try Task.checkCancellation()
        // The application TTL cache will own freshness. Never read URLSession's cache,
        // including when callers inject a session configured with a URLCache.
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalCacheData)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        let data: Foundation.Data
        let response: URLResponse
        do {
            (data, response) = try await transport.data(for: request)
        } catch {
            if error is CancellationError || Task.isCancelled || (error as? URLError)?.code == .cancelled {
                throw CancellationError()
            }
            if let urlError = error as? URLError {
                throw HTTPClientError.transport(urlError.code)
            }
            throw HTTPClientError.unexpected(error)
        }

        // A transport can ignore cancellation and still return a successful response.
        try Task.checkCancellation()
        guard let response = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }
        guard (200 ..< 300).contains(response.statusCode) else {
            print("❌ Failed to fetch data from \(url), statusCode: \(response.statusCode)")
            throw HTTPClientError.httpStatus(code: response.statusCode, body: data)
        }

        let decoded: Response
        do {
            decoded = try JSONDecoder().decode(Response.self, from: data)
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            throw HTTPClientError.decoding(error)
        }
        try Task.checkCancellation()
        return decoded
    }
}
