import CoreGraphics
import Domain
@testable import Presentation
import SwiftUI
import Testing

@MainActor
struct TypographyTests {
    @Test(arguments: [Domain.Character.Status.alive, .dead, .unknown], [ColorScheme.light, .dark])
    func renderedBadgesMeetSmallTextContrast(status: Domain.Character.Status, scheme: ColorScheme) throws {
        let image = try render(StatusBadge(status: status).environment(\.colorScheme, scheme))
        let luminances = try dominantColors(in: image).map(luminance)
        let lighter = try #require(luminances.max())
        let darker = try #require(luminances.min())
        #expect((lighter + 0.05) / (darker + 0.05) >= 4.5)
    }

    @Test(arguments: [Domain.Character.Status.alive, .dead, .unknown])
    func badgeTextGrowsAtAccessibilitySizes(status: Domain.Character.Status) throws {
        let badge = StatusBadge(status: status)
        let standard = try render(badge.environment(\.dynamicTypeSize, .large))
        let accessible = try render(badge.environment(\.dynamicTypeSize, .accessibility5))
        #expect(accessible.height > standard.height)
        #expect(accessible.width > standard.width)
    }

    @Test
    func rowExpandsAtAccessibilitySizesOnNarrowWidth() throws {
        let row = CharacterRow(character: .fixture(id: 1))
        let standard = try render(row.environment(\.dynamicTypeSize, .large).frame(width: 280))
        let accessible = try render(row.environment(\.dynamicTypeSize, .accessibility5).frame(width: 280))
        #expect(accessible.height > standard.height)
        #expect(accessible.width == standard.width)
    }

    private func render(_ content: some View) throws -> CGImage {
        let renderer = ImageRenderer(content: content.fixedSize(horizontal: false, vertical: true))
        renderer.scale = 2
        return try #require(renderer.cgImage)
    }

    private func dominantColors(in image: CGImage) throws -> [SIMD3<Double>] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let space = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(
                data: buffer.baseAddress, width: image.width, height: image.height,
                bitsPerComponent: 8, bytesPerRow: image.width * 4, space: space,
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        }
        var frequencies: [UInt32: Int] = [:]
        for offset in stride(from: 0, to: bytes.count, by: 4) where bytes[offset + 3] == 255 {
            let rgb = UInt32(bytes[offset]) << 16 | UInt32(bytes[offset + 1]) << 8 | UInt32(bytes[offset + 2])
            frequencies[rgb, default: 0] += 1
        }
        // Solid capsule fill and solid glyph interiors dominate; ignore blended edges.
        let colors = frequencies.sorted { $0.value > $1.value }.prefix(2).map(\.key)
        try #require(colors.count == 2)
        return colors.map { rgb in
            SIMD3(Double((rgb >> 16) & 255), Double((rgb >> 8) & 255), Double(rgb & 255)) / 255
        }
    }

    private func luminance(_ rgb: SIMD3<Double>) -> Double {
        let linear = (0 ..< 3).map { index in
            let value = rgb[index]
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return linear[0] * 0.2126 + linear[1] * 0.7152 + linear[2] * 0.0722
    }
}
