import Domain
import Foundation

enum CharacterMappingError: Error, Equatable {
    case invalidCharacter
    case invalidPagination
}

extension CharacterDTO {
    func toDomain() throws -> Domain.Character {
        guard id > 0,
              let imageURL = URL(string: image),
              ["http", "https"].contains(imageURL.scheme),
              let host = imageURL.host, !host.isEmpty
        else {
            throw CharacterMappingError.invalidCharacter
        }
        let domainStatus: Domain.Character.Status = switch status.lowercased() {
        case "alive": .alive
        case "dead": .dead
        default: .unknown
        }
        let domainGender: Domain.Character.Gender = switch gender.lowercased() {
        case "female": .female
        case "male": .male
        case "genderless": .genderless
        default: .unknown
        }
        return Domain.Character(
            id: id, name: name, imageURL: imageURL, status: domainStatus,
            species: species, gender: domainGender, origin: origin.name, location: location.name
        )
    }
}

extension CharacterPageDTO {
    func toDomain(requestedPage: Int) throws -> CharacterPage {
        let nextPage: Int?
        if let next = info.next {
            guard let components = URLComponents(string: next),
                  ["http", "https"].contains(components.scheme),
                  let host = components.host, !host.isEmpty,
                  let items = components.queryItems?.filter({ $0.name == "page" }), items.count == 1,
                  let value = items.first?.value, let page = Int(value), page > requestedPage
            else {
                throw CharacterMappingError.invalidPagination
            }
            nextPage = page
        } else {
            nextPage = nil
        }
        return try CharacterPage(characters: results.map { try $0.toDomain() }, nextPage: nextPage)
    }
}
