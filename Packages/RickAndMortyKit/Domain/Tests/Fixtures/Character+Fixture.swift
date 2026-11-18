import Domain
import Foundation
import Testing

extension Domain.Character {
    static func fixture() throws -> Self {
        try Self(
            id: 1,
            name: "Rick Sanchez",
            imageURL: #require(URL(string: "https://example.com/1.jpeg")),
            status: .alive,
            species: "Human",
            gender: .male,
            origin: "Earth",
            location: "Citadel"
        )
    }
}
