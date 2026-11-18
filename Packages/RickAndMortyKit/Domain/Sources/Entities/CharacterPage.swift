public struct CharacterPage: Equatable, Sendable {
    public let characters: [Character]

    /// The next one-based page number, or nil when there are no more results.
    public let nextPage: Int?

    public init(characters: [Character], nextPage: Int?) {
        self.characters = characters
        self.nextPage = nextPage
    }
}
