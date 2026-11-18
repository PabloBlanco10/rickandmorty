import Foundation

public struct Character: Identifiable, Equatable, Sendable {
    public enum Status: Equatable, Sendable {
        case alive, dead, unknown
    }

    public enum Gender: Equatable, Sendable {
        case female, male, genderless, unknown
    }

    public let id: Int
    public let name: String
    public let imageURL: URL
    public let status: Status
    public let species: String
    public let gender: Gender
    public let origin: String
    public let location: String

    public init(
        id: Int,
        name: String,
        imageURL: URL,
        status: Status,
        species: String,
        gender: Gender,
        origin: String,
        location: String
    ) {
        self.id = id
        self.name = name
        self.imageURL = imageURL
        self.status = status
        self.species = species
        self.gender = gender
        self.origin = origin
        self.location = location
    }
}
