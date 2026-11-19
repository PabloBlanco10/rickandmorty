import Foundation

enum HTTPClientError: Error {
    case invalidURL
    case invalidResponse
    case httpStatus(code: Int, body: Foundation.Data)
    case transport(URLError.Code)
    case decoding(any Error)
    case unexpected(any Error)
}
