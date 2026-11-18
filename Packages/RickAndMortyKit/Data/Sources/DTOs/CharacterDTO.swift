import Foundation

struct CharacterDTO: Decodable, Sendable {
    let id: Int
    let name: String
    let image: String
    let status: String
    let species: String
    let gender: String
    let origin: CharacterLocationDTO
    let location: CharacterLocationDTO
}

struct CharacterLocationDTO: Decodable, Sendable {
    let name: String
}
