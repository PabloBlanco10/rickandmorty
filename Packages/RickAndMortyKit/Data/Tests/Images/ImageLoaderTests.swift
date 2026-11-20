@testable import Data
import Foundation
import Testing

struct ImageLoaderTests {
    @Test
    func loadsBytesThroughInjectedSessionUsingCacheFirstRequestPolicy() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let loader = URLSessionImageLoader(session: session)
        let data = try await loader.loadImage(from: APIResponseFixture.url("https://example.com/success"))
        #expect(data == Foundation.Data([1, 2, 3]))
    }

    @Test(arguments: ["404", "429", "500", "empty", "non-http"])
    func rejectsUnsuccessfulOrEmptyResponses(path: String) async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let loader = URLSessionImageLoader(session: session)
        let url = try APIResponseFixture.url("https://example.com/\(path)")
        do {
            _ = try await loader.loadImage(from: url)
            Issue.record("Expected invalid response rejection")
        } catch let error as URLError {
            #expect(error.code == .badServerResponse)
        }
    }

    @Test
    func preservesNativeURLSessionCancellationError() async throws {
        let session = makeSession()
        defer { session.invalidateAndCancel() }
        let loader = URLSessionImageLoader(session: session)
        let url = try APIResponseFixture.url("https://example.com/cancelled")
        do {
            _ = try await loader.loadImage(from: url)
            Issue.record("Expected URLSession cancellation")
        } catch let error as URLError {
            #expect(error.code == .cancelled)
        }
    }

    private func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.protocolClasses = [ImageURLProtocol.self]
        return URLSession(configuration: configuration)
    }
}
