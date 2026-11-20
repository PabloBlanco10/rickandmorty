import Foundation

/// Image bytes only; decoding and platform-specific image types belong to Presentation.
public protocol ImageLoader: Sendable {
    func loadImage(from url: URL) async throws -> Data
}
