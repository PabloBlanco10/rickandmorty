import Domain
import Foundation

/// Cache-first avatars use URLSession's HTTP caching; retention is not guaranteed.
public struct URLSessionImageLoader: ImageLoader {
    private let session: URLSession

    public init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }
        let configuration = URLSessionConfiguration.default
        configuration.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024, diskCapacity: 100 * 1024 * 1024,
            directory: URL.cachesDirectory.appending(path: "CharacterImages")
        )
        configuration.requestCachePolicy = .returnCacheDataElseLoad
        self.session = URLSession(configuration: configuration)
    }

    public func loadImage(from url: URL) async throws -> Foundation.Data {
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        let (data, response) = try await session.data(for: request)
        guard let response = response as? HTTPURLResponse,
              (200 ..< 300).contains(response.statusCode),
              !data.isEmpty
        else { throw URLError(.badServerResponse) }
        return data
    }
}
