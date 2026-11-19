import Domain
import Foundation
import SwiftUI

@MainActor
enum CharactersPreviewFixtures {
    static let character = Character(
        id: 1, name: "Rick Sanchez", imageURL: URL(fileURLWithPath: "/preview/rick.jpg"),
        status: .alive, species: "Human", gender: .male, origin: "Earth", location: "Citadel of Ricks"
    )

    static func view(state: ViewState<[Character]>) -> some View {
        let model = CharactersViewModel(
            useCase: SearchCharactersUseCase(repository: PreviewCharacterRepository()),
            initialState: state,
            debounce: {}
        )
        return CharactersView(viewModel: model)
    }
}

private struct PreviewCharacterRepository: CharacterRepository {
    func searchCharacters(query _: String, page _: Int, policy _: FetchPolicy) async throws -> CharacterPage {
        CharacterPage(characters: [], nextPage: nil)
    }
}
