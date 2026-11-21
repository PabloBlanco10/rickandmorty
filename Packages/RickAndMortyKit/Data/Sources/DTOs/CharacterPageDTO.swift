struct CharacterPageInfoDTO: Decodable, Sendable {
    let next: String?
}

struct CharacterPageDTO: Decodable, Sendable {
    let info: CharacterPageInfoDTO
    let results: [CharacterDTO]
}
