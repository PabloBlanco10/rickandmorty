@testable import Data
import Foundation
import Testing

struct HTTPClientTests {
    @Test
    func decodesGenericResponseAndBuildsUncachedGET() async throws {
        let transport = try HTTPTransportSpy(
            data: Foundation.Data(#"{"value":42}"#.utf8), response: APIResponseFixture.response()
        )
        let client = HTTPClient(transport: transport)
        let url = try APIResponseFixture.url()

        let result: Payload = try await client.get(from: url)

        #expect(result.value == 42)
        let requests = await transport.requests
        let request = try #require(requests.first)
        #expect(requests.count == 1)
        #expect(request.url == url)
        #expect(request.httpMethod == "GET")
        #expect(request.cachePolicy == .reloadIgnoringLocalCacheData)
        #expect(request.value(forHTTPHeaderField: "Cache-Control") == "no-cache")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
    }

    @Test(arguments: [199, 300, 401, 404, 500])
    func validatesStatusBeforeDecoding(status: Int) async throws {
        let body = Foundation.Data("not JSON".utf8)
        let transport = try HTTPTransportSpy(data: body, response: APIResponseFixture.response(status: status))
        do {
            let _: Payload = try await HTTPClient(transport: transport).get(from: APIResponseFixture.url())
            Issue.record("Expected an HTTP status error")
        } catch let HTTPClientError.httpStatus(code, responseBody) {
            #expect(code == status)
            #expect(responseBody == body)
        }
    }

    @Test
    func rejectsNonHTTPResponse() async throws {
        let url = try APIResponseFixture.url()
        let transport = HTTPTransportSpy(response: URLResponse(
            url: url, mimeType: nil, expectedContentLength: 0, textEncodingName: nil
        ))
        do {
            let _: Payload = try await HTTPClient(transport: transport).get(from: url)
            Issue.record("Expected an invalid response error")
        } catch HTTPClientError.invalidResponse {
            // The typed category is the observable contract.
        }
    }

    @Test(arguments: ["not JSON", #"{"value":"wrong type"}"#])
    func reportsDecodingFailures(body: String) async throws {
        let transport = try HTTPTransportSpy(data: Foundation.Data(body.utf8), response: APIResponseFixture.response())
        do {
            let _: Payload = try await HTTPClient(transport: transport).get(from: APIResponseFixture.url())
            Issue.record("Expected a decoding error")
        } catch let HTTPClientError.decoding(underlying) {
            #expect(underlying is DecodingError)
        }
    }

    @Test(arguments: [URLError.notConnectedToInternet, .timedOut])
    func preservesTransportErrorCode(code: URLError.Code) async throws {
        let transport = HTTPTransportSpy(error: URLError(code))
        do {
            let _: Payload = try await HTTPClient(transport: transport).get(from: APIResponseFixture.url())
            Issue.record("Expected a transport error")
        } catch let HTTPClientError.transport(actual) {
            #expect(actual == code)
        }
    }

    @Test
    func normalizesURLSessionCancellation() async throws {
        let transport = HTTPTransportSpy(error: URLError(.cancelled))
        let url = try APIResponseFixture.url()
        await #expect(throws: CancellationError.self) {
            let _: Payload = try await HTTPClient(transport: transport).get(from: url)
        }
    }

    @Test
    func preservesCancellationError() async throws {
        let transport = HTTPTransportSpy(error: CancellationError())
        let url = try APIResponseFixture.url()
        await #expect(throws: CancellationError.self) {
            let _: Payload = try await HTTPClient(transport: transport).get(from: url)
        }
    }

    @Test
    func rejectsLateSuccessAfterCancellation() async throws {
        let transport = ControlledHTTPTransport()
        let client = HTTPClient(transport: transport)
        let url = try APIResponseFixture.url()
        let response = try APIResponseFixture.response()
        let task = Task { () -> Payload in try await client.get(from: url) }

        await transport.waitUntilRequested()
        task.cancel()
        await transport.succeed(data: Foundation.Data(#"{"value":42}"#.utf8), response: response)

        await #expect(throws: CancellationError.self) { try await task.value }
    }

    @Test
    func preservesCancellationThrownByDecodable() async throws {
        let transport = try HTTPTransportSpy(data: Foundation.Data("{}".utf8), response: APIResponseFixture.response())
        let url = try APIResponseFixture.url()
        await #expect(throws: CancellationError.self) {
            let _: CancellingPayload = try await HTTPClient(transport: transport).get(from: url)
        }
    }

    @Test
    func defaultSessionDisablesHTTPCache() {
        let transport = URLSessionTransport()
        let configuration = transport.session.configuration
        #expect(configuration.urlCache == nil)
        #expect(configuration.requestCachePolicy == .reloadIgnoringLocalCacheData)
        transport.session.invalidateAndCancel()
    }

    @Test
    func acceptsConstructorInjectedSession() {
        let session = URLSession(configuration: .ephemeral)
        let transport = URLSessionTransport(session: session)
        #expect(transport.session === session)
        session.invalidateAndCancel()
    }
}

private struct Payload: Decodable, Sendable {
    let value: Int
}

private struct CancellingPayload: Decodable, Sendable {
    init(from _: any Decoder) throws {
        throw CancellationError()
    }
}
