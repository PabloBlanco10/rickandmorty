#if DEBUG
    import Domain
    import Foundation

    /// UI-test launches use the normal native image placeholder without any image HTTP requests.
    struct UITestImageLoader: ImageLoader {
        func loadImage(from _: URL) async throws -> Data {
            try Task.checkCancellation()
            throw URLError(.resourceUnavailable)
        }
    }

    /// Per-launch deterministic state. Never constructed without the explicit UI-test argument.
    actor UITestCharacterRepository: CharacterRepository {
        private var failInitialRequest: Bool
        private let characters: [Character]

        init(failInitialRequest: Bool) {
            self.failInitialRequest = failInitialRequest
            let imageURL = URL(fileURLWithPath: "/ui-tests/character.png")
            characters = [
                Character(
                    id: 1, name: "Rick Sanchez", imageURL: imageURL, status: .alive, species: "Human",
                    gender: .male, origin: "Earth (C-137)", location: "Citadel of Ricks"
                ),
                Character(
                    id: 2, name: "Morty Smith", imageURL: imageURL, status: .alive, species: "Human",
                    gender: .male, origin: "Earth (C-137)", location: "Earth"
                )
            ]
        }

        func searchCharacters(query: String, page: Int) async throws -> CharacterPage {
            try Task.checkCancellation()
            if failInitialRequest {
                failInitialRequest = false
                throw CharacterRepositoryError.networkUnavailable
            }
            let matches = page == 1
                ? characters.filter { query.isEmpty || $0.name.lowercased().contains(query) }
                : []
            return CharacterPage(characters: matches, nextPage: nil)
        }
    }
#endif
