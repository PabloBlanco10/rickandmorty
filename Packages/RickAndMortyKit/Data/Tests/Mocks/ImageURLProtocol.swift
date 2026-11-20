import Foundation

/// Immutable, per-request responses. Installed on each test's own session, never globally.
final class ImageURLProtocol: URLProtocol {
    override static func canInit(with _: URLRequest) -> Bool {
        true
    }

    override static func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let url = request.url, request.cachePolicy == .returnCacheDataElseLoad,
              request.value(forHTTPHeaderField: "Cache-Control") == nil
        else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        if url.lastPathComponent == "cancelled" {
            client?.urlProtocol(self, didFailWithError: URLError(.cancelled))
            return
        }
        let response: URLResponse
        if url.lastPathComponent == "non-http" {
            response = URLResponse(url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil)
        } else {
            guard let http = HTTPURLResponse(
                url: url, statusCode: Int(url.lastPathComponent) ?? 200, httpVersion: nil,
                headerFields: ["Content-Type": "image/png"]
            ) else { return }
            response = http
        }
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        if url.lastPathComponent != "empty" {
            client?.urlProtocol(self, didLoad: Data([1, 2, 3]))
        }
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
