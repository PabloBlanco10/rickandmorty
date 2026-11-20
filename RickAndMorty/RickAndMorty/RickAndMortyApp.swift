import Data
import Domain
import Foundation
import Presentation
import SwiftUI

@main
@MainActor
struct RickAndMortyApp: App {
    private let imageLoader = URLSessionImageLoader()
    @State private var viewModel: CharactersViewModel

    init() {
        guard let apiRoot = URL(string: "https://rickandmortyapi.com/api") else {
            preconditionFailure("The configured API root must be a valid URL")
        }
        let repository = RickAndMortyCharacterRepository(baseURL: apiRoot)
        _viewModel = State(initialValue: CharactersViewModel(useCase: SearchCharactersUseCase(repository: repository)))
    }

    var body: some Scene {
        WindowGroup {
            CharactersView(viewModel: viewModel, imageLoader: imageLoader)
        }
    }
}
