@testable import Data
import Domain
import Foundation
import Testing

struct CharacterMappingTests {
    @Test
    func mapsCharacterFieldsAndPagination() throws {
        let dto = try JSONDecoder().decode(CharacterPageDTO.self, from: APIResponseFixture.pageData())
        let page = try dto.toDomain(requestedPage: 1)
        let character = try #require(page.characters.first)
        #expect(page.characters.count == 1)
        #expect(page.nextPage == 2)
        #expect(character.id == 1)
        #expect(character.name == "Rick Sanchez")
        #expect(try character.imageURL == (APIResponseFixture.url("https://example.com/1.jpeg")))
        #expect(character.status == .alive)
        #expect(character.species == "Human")
        #expect(character.gender == .male)
        #expect(character.origin == "Earth")
        #expect(character.location == "Citadel")
    }

    @Test(arguments: ["Alive", "Dead", "unknown", "future value"])
    func mapsStatus(status: String) throws {
        let dto = try JSONDecoder().decode(CharacterPageDTO.self, from: APIResponseFixture.pageData(status: status))
        let expected: Domain.Character.Status = switch status {
        case "Alive": .alive
        case "Dead": .dead
        default: .unknown
        }
        #expect(try dto.toDomain(requestedPage: 1).characters.first?.status == expected)
    }

    @Test(arguments: ["Female", "Male", "Genderless", "unknown", "future value"])
    func mapsGender(gender: String) throws {
        let dto = try JSONDecoder().decode(CharacterPageDTO.self, from: APIResponseFixture.pageData(gender: gender))
        let expected: Domain.Character.Gender = switch gender {
        case "Female": .female
        case "Male": .male
        case "Genderless": .genderless
        default: .unknown
        }
        #expect(try dto.toDomain(requestedPage: 1).characters.first?.gender == expected)
    }

    @Test
    func mapsLastPageAndEmptyResults() throws {
        let dto = try JSONDecoder().decode(
            CharacterPageDTO.self,
            from: APIResponseFixture.pageData(next: nil, empty: true)
        )
        #expect(try dto.toDomain(requestedPage: 8) == CharacterPage(characters: [], nextPage: nil))
    }

    @Test(arguments: ["", "file:///image.jpg", "relative/image.jpg", "https://"])
    func rejectsInvalidImageURL(image: String) throws {
        let dto = try JSONDecoder().decode(CharacterPageDTO.self, from: APIResponseFixture.pageData(image: image))
        #expect(throws: CharacterMappingError.invalidCharacter) { try dto.toDomain(requestedPage: 1) }
    }

    @Test(arguments: [0, -1])
    func rejectsInvalidCharacterIdentifier(id: Int) throws {
        let dto = try JSONDecoder().decode(CharacterPageDTO.self, from: APIResponseFixture.pageData(id: id))
        #expect(throws: CharacterMappingError.invalidCharacter) { try dto.toDomain(requestedPage: 1) }
    }

    @Test(arguments: [
        "not a URL", "https://example.com/api/character", "https://example.com/api/character?page=no",
        "https://example.com/api/character?page=0", "https://example.com/api/character?page=1",
        "https://example.com/api/character?page=2&page=3"
    ])
    func rejectsMalformedOrNonAdvancingPagination(next: String) throws {
        let dto = try JSONDecoder().decode(CharacterPageDTO.self, from: APIResponseFixture.pageData(next: next))
        #expect(throws: CharacterMappingError.invalidPagination) { try dto.toDomain(requestedPage: 1) }
    }
}
