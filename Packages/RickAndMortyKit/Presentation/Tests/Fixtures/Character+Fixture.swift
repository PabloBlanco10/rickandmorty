import Domain
import Foundation

extension Character {
    static func fixture(id: Int) -> Character {
        Character(
            id: id, name: "Character \(id)", imageURL: URL(fileURLWithPath: "/fixtures/\(id).jpg"),
            status: .alive, species: "Human", gender: .unknown, origin: "Earth", location: "Earth"
        )
    }
}
