@testable import Data
import Foundation
import Testing

struct ImageLoaderTests {
    @Test
    func storesSuccessfulResponseAndReusesActualURLCacheEntry() async throws {
        let cache = makeCache()
        let url = try APIResponseFixture.url("https://example.com/avatar.png")
        let data = Foundation.Data([1, 2, 3])
        let transport = try HTTPTransportSpy(data: data, response: response(url: url))
        let loader = URLSessionImageLoader(cache: cache, transport: transport)
        #expect(try await loader.loadImage(from: url) == data)
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad)
        #expect(cache.cachedResponse(for: request)?.data == data)
        #expect(try await loader.loadImage(from: url) == data)
        #expect(await transport.requests.count == 1)
        #expect(await transport.requests.first?.cachePolicy == .returnCacheDataElseLoad)
        #expect(await transport.requests.first?.value(forHTTPHeaderField: "Cache-Control") == nil)
    }

    @Test
    func noStoreResponsesAreNotExplicitlyCached() async throws {
        let cache = makeCache()
        let url = try APIResponseFixture.url("https://example.com/avatar.png")
        let transport = try HTTPTransportSpy(
            data: Foundation.Data([1]),
            response: response(url: url, cacheControl: "no-store")
        )
        let loader = URLSessionImageLoader(cache: cache, transport: transport)
        _ = try await loader.loadImage(from: url)
        _ = try await loader.loadImage(from: url)
        #expect(cache.cachedResponse(for: URLRequest(url: url)) == nil)
        #expect(await transport.requests.count == 2)
    }

    @Test(arguments: [429, 500])
    func failuresAreNotCached(status: Int) async throws {
        let cache = makeCache()
        let url = try APIResponseFixture.url("https://example.com/avatar.png")
        let transport = try HTTPTransportSpy(data: Foundation.Data([1]), response: response(url: url, status: status))
        let loader = URLSessionImageLoader(cache: cache, transport: transport)
        await #expect(throws: URLError.self) { try await loader.loadImage(from: url) }
        #expect(cache.cachedResponse(for: URLRequest(url: url)) == nil)
    }

    @Test
    func cancelledLateSuccessDoesNotEnterCache() async throws {
        let cache = makeCache()
        let url = try APIResponseFixture.url("https://example.com/avatar.png")
        let transport = ControlledHTTPTransport()
        let loader = URLSessionImageLoader(cache: cache, transport: transport)
        let task = Task { try await loader.loadImage(from: url) }
        await transport.waitUntilRequested()
        task.cancel()
        try await transport.succeed(data: Foundation.Data([1]), response: response(url: url))
        await #expect(throws: CancellationError.self) { try await task.value }
        #expect(cache.cachedResponse(for: URLRequest(url: url)) == nil)
    }

    @Test
    func normalizesTransportCancellation() async throws {
        let loader = URLSessionImageLoader(cache: makeCache(), transport: HTTPTransportSpy(error: URLError(.cancelled)))
        let url = try APIResponseFixture.url("https://example.com/avatar.png")
        await #expect(throws: CancellationError.self) { try await loader.loadImage(from: url) }
    }

    private func makeCache() -> URLCache {
        URLCache(memoryCapacity: 1024 * 1024, diskCapacity: 0, diskPath: nil)
    }

    private func response(url: URL, status: Int = 200,
                          cacheControl: String = "public, max-age=3600") throws -> HTTPURLResponse
    {
        try #require(HTTPURLResponse(
            url: url, statusCode: status, httpVersion: "HTTP/1.1",
            headerFields: ["Content-Type": "image/png", "Cache-Control": cacheControl]
        ))
    }
}
