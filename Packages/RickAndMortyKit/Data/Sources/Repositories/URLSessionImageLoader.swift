import Domain
import Foundation

/// Avatars favor reuse, including stale responses, until URLCache evicts them.
/// This policy is deliberately independent of JSON API cache bypass.
public struct URLSessionImageLoader: ImageLoader {
    private let cache: URLCache
    private let transport: any HTTPTransport

    public init() {
        let cache = URLCache(
            memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024,
            directory: URL.cachesDirectory.appending(path: "CharacterImages")
        )
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = cache
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        self.init(cache: cache, transport: URLSessionTransport(session: URLSession(configuration: configuration)))
    }

    init(cache: URLCache, transport: any HTTPTransport) {
        self.cache = cache
        self.transport = transport
    }

    public func loadImage(from url: URL) async throws -> Foundation.Data {
        try Task.checkCancellation()
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        if let cached = cache.cachedResponse(for: request) {
            if imageResponse(cached.response, data: cached.data) != nil {
                try Task.checkCancellation()
                return cached.data
            }
            cache.removeCachedResponse(for: request)
        }
        do {
            let (data, response) = try await transport.data(for: request)
            try Task.checkCancellation()
            guard let response = imageResponse(response, data: data) else {
                cache.removeCachedResponse(for: request)
                throw URLError(.badServerResponse)
            }
            // Explicit storage makes reuse testable even when URLSession chooses
            // not to store automatically. Respect the server's no-store directive.
            let directives = response.value(forHTTPHeaderField: "Cache-Control")?.lowercased() ?? ""
            if !directives.contains("no-store") {
                cache.storeCachedResponse(CachedURLResponse(response: response, data: data), for: request)
            }
            return data
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled || Task.isCancelled {
                throw CancellationError()
            }
            throw error
        }
    }

    private func imageResponse(_ response: URLResponse, data: Foundation.Data) -> HTTPURLResponse? {
        guard let response = response as? HTTPURLResponse,
              (200 ..< 300).contains(response.statusCode),
              response.mimeType?.hasPrefix("image/") == true, !data.isEmpty else { return nil }
        return response
    }
}
